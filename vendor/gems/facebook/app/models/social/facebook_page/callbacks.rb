class Social::FacebookPage < ActiveRecord::Base

  include Social::Constants
  include MixpanelWrapper

  before_create :create_mapping
  before_destroy :unregister_stream_subscription
  after_destroy :remove_mapping

  after_commit :subscribe_realtime, :send_mixpanel_event, on: :create
  after_commit :build_default_streams,  on: :create,  :if => :facebook_revamp_enabled?
  after_commit :delete_default_streams, on: :destroy, :if => :facebook_revamp_enabled?
  after_commit :update_ticket_rules,    on: :update,  :if => :facebook_revamp_enabled?

  after_update :fetch_fb_wall_posts
  after_commit :clear_cache

  def cleanup(push_to_resque=false)
    unsubscribe_realtime
    if push_to_resque
      Social::FacebookDelta.perform_async({ :page_id => self.page_id, :discard_feed => true })
    else
      Social::FacebookDelta.new.add_feeds_to_sqs(self.page_id, true)
    end
  end

  def subscribe_realtime
    if enable_page && company_or_visitor?
      Facebook::PageTab::Configure.new(self).execute("subscribe_realtime")
    end
  end
  
  def build_default_streams
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      build_stream(page_name, FB_STREAM_TYPE[:default])
      build_stream(page_name, FB_STREAM_TYPE[:dm])
    else
      error_params = {
        :facebook_page => id,
        :account_id    => account_id,
        :stream        => def_stream.inspect
      }
      notify_social_dev("Default Stream already present for the facebook page", error_params)
    end
  end
  
  private
  
  def build_stream(name, type, options = nil)
    stream_params = facebook_stream_params(name, type, options)
    stream = facebook_streams.build(stream_params)
    stream.save
  end
  
  def update_ticket_rules
    update_default_steam_for_changes 
    update_dm_steam_for_changes
  end
  
  def update_default_steam_for_changes
    default_stream.update_ticket_rule if default_tkt_rule_changed? or product_changed?
  end
  
  def update_dm_steam_for_changes
    dm_stream.update_ticket_rule if dm_tkt_rule_changed? or product_changed?
  end

  def data(type, options)
    data = {
        :kind => type
    }
    data.merge!(options) if options
    data
  end
  
  def default_tkt_rule_changed?
    (self.previous_changes.keys & ["import_visitor_posts", "import_company_posts"]).present?
  end
  
  def dm_tkt_rule_changed?
    self.previous_changes.keys.include?("import_dms")
  end
  
  def product_changed?
    self.previous_changes.keys.include?("product_id")
  end
  
  def facebook_stream_params(name, type, options)
    params = {
      :name     => name,
      :includes => [],
      :excludes => [],
      :filter   => {},
      :data     => data(type, options)
    }
    params.merge!({
        :accessible_attributes => {
          :access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        }
      }) if type == FB_STREAM_TYPE[:default]
    params
  end
  
  def delete_default_streams
    streams = facebook_streams
    streams.each do |stream|
      if stream.data[:kind] != FB_STREAM_TYPE[:custom]
        stream.destroy
      end
    end
  end
  
  def create_mapping
    fb_page_mapping = Social::FacebookPageMapping.find_by_facebook_page_id(page_id)
    
    if fb_page_mapping
      errors.add(:base,"Facebook page already in use") 
    else
      facebook_page_mapping = Social::FacebookPageMapping.new(:account_id => account_id)
      facebook_page_mapping.facebook_page_id = page_id
      facebook_page_mapping.save
    end    
  end

  def remove_mapping
    fb_page_mapping = Social::FacebookPageMapping.find_by_facebook_page_id(page_id)
    fb_page_mapping.destroy if fb_page_mapping
  end


  # unsubscribing the realtime feed and pushing into the resque
  def unregister_stream_subscription
    # delete entries from dynamo here true means pushing to resque
    cleanup(true)
  end

  def unsubscribe_realtime
    Facebook::PageTab::Configure.new(self).execute("unsubscribe_realtime")
  end

  def fetch_fb_wall_posts
    #remove the code for checking
    if fetch_delta?
      Facebook::PageTab::Configure.new(self).execute("subscribe_realtime") unless self.realtime_subscription
      Social::FacebookDelta.perform_async({ :page_id => self.page_id }) if self.company_or_visitor?
    end
  end

  def send_mixpanel_event
    ::MixpanelWrapper.send_to_mixpanel(self.class.name)
  end

  def facebook_revamp_enabled?
    Account.current.features?(:social_revamp)
  end
  
end

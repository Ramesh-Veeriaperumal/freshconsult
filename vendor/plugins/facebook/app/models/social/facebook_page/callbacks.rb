class Social::FacebookPage < ActiveRecord::Base
  include MixpanelWrapper

  before_create :create_mapping
  before_destroy :unregister_stream_subscription
  after_destroy :remove_mapping

  after_commit_on_create :subscribe_realtime, :send_mixpanel_event
  after_update :fetch_fb_wall_posts
  after_commit :clear_cache

  def cleanup(push_to_resque=false)
    return unless account.features?(:facebook_realtime)
    unsubscribe_realtime
    if push_to_resque
      Resque.enqueue(Facebook::Worker::FacebookDelta, {
                       :account_id => self.account_id,
                       :page_id => self.page_id,
                       :discard_feed => true
      })
    else
      Facebook::Worker::FacebookDelta.add_feeds_to_sqs(self.page_id, true)
    end
  end

  def subscribe_realtime
    if enable_page && company_or_visitor? && account.features?(:facebook_realtime)
      Facebook::PageTab::Configure.new(self).execute("add")
    end
  end

  private
  
  def create_mapping
    facebook_page_mapping = Social::FacebookPageMapping.new(:account_id => account_id)
    facebook_page_mapping.facebook_page_id = page_id
    errors.add_to_base("Facebook page already in use") unless facebook_page_mapping.save
  end

  def remove_mapping
    fb_page_mapping = Social::FacebookPageMapping.find(page_id)
    fb_page_mapping.destroy if fb_page_mapping
  end


  # unsubscribing the realtime feed and pushing into the resque
  def unregister_stream_subscription
    # delete entries from dynamo here true means pushing to resque
    cleanup(true)
  end

  def unsubscribe_realtime
    Facebook::PageTab::Configure.new(self).execute("remove")
  end

  def fetch_fb_wall_posts
    #remove the code for checking
    if fetch_delta? && account.features?(:facebook_realtime)
      Facebook::PageTab::Configure.new(self).execute("add")
      Resque.enqueue(Facebook::Worker::FacebookDelta, {
                       :account_id => self.account_id,
                       :page_id => self.page_id
      })
    end
  end

  def send_mixpanel_event
    send_to_mixpanel(self.class.name)
  end

end

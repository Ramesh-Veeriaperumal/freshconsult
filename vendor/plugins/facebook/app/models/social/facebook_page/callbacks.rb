class Social::FacebookPage < ActiveRecord::Base
  
  include Facebook::Constants

  before_create :create_mapping
  before_destroy :unregister_stream_subscription
  after_destroy :remove_mapping
  after_commit_on_destroy :delete_default_streams

  after_commit_on_create :subscribe_realtime, :build_default_streams
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
  
  
  def build_default_streams
    return unless account.features?(:social_revamp)
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      options = {
        :replies_enabled => false
      }
      build_stream(page_name, STREAM_TYPE[:default], options)
      build_stream(page_name, STREAM_TYPE[:dm])
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
    stream = facebook_streams.build(
      :name     => name,
      :includes => [],
      :excludes => [],
      :filter   => {},
      :data     => data(type, options)
      )
    stream.save
  end

  def data(type, options)
    data = {
        :kind => type
    }
    data.merge!(options) if options
    data
  end
  
  def delete_default_streams
    return unless account.features?(:social_revamp)
    streams = facebook_streams
    streams.each do |stream|
      if stream.data[:kind] != STREAM_TYPE[:custom]
        stream.destroy
      end
    end
  end
  
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

end

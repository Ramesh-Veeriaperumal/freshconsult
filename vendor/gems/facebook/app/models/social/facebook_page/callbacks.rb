class Social::FacebookPage < ActiveRecord::Base

  # To indicate an FB page can be linked to only one Freshdesk account across POD's.
  class AlreadyLinkedException < StandardError
  end

  # No response from facebook API's.
  class NoResponseException < StandardError
  end

  include Social::Constants
  include MixpanelWrapper
  include Facebook::GatewayJwt
  include Admin::Social::FacebookGatewayHelper

  before_destroy :unregister_stream_subscription
  before_save :create_model_changes, on: :update

  after_commit :subscribe_realtime, :send_mixpanel_event, on: :create
  after_commit :build_default_streams,  on: :create
  after_commit :delete_default_streams, on: :destroy
  after_commit :remove_gateway_page_subscription, on: :destroy

  after_update :fetch_fb_wall_posts
  after_commit :clear_cache
  before_destroy :save_deleted_page_info
  publishable on: :update, :if => :can_central_publish?

  def cleanup(push_to_sidekiq = false)
    if can_cleanup?
      unsubscribe_realtime
      if push_to_sidekiq
        Social::FacebookDelta.perform_async({ :page_id => self.page_id, :discard_feed => true })
      else
        Social::FacebookDelta.new.add_feeds_to_sqs(self.page_id, true)
      end
    end
  end
  
  def build_default_streams
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      build_stream(page_name, FB_STREAM_TYPE[:default])
      build_stream(page_name, FB_STREAM_TYPE[:dm])
      build_stream(page_name, FB_STREAM_TYPE[:ad_post])
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

  def can_cleanup?
    status, gateway_fb_accounts_count, gateway_fb_accounts = gateway_facebook_page_mapping_details(page_id)
    notify_gateway_failure if status != 200
    gateway_fb_accounts_count == 1 && gateway_fb_accounts.include?(Account.current.id)
  end

  def notify_gateway_failure
    message = OpenStruct.new(message: "Gateway couldn't be connected to verify facebook page unsubscription")
    SocialErrorsMailer.deliver_facebook_exception(message, page_id: page_id, account_id: Account.current.id, token: access_token) unless Rails.env.test?
    Rails.logger.warn("Gateway couldn't be connected to verify facebook page unsubscription for \
      facebookPage::#{page_id}, account::#{Account.current.id}, token::#{access_token}")
  end
  
  def build_stream(name, type)
    stream_params = facebook_stream_params(name, type)
    stream = facebook_streams.build(stream_params)
    stream.save
  end
  
  def facebook_stream_params(name, type)
    params = {
      :name     => name,
      :includes => [],
      :excludes => [],
      :filter   => {},
      :data     =>  {
        :kind => type
      }
    }
    params.merge!({
        :accessible_attributes => {
          :access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        }
      }) if type == FB_STREAM_TYPE[:default]
    params
  end
  
  def delete_default_streams
    self.facebook_streams.destroy_all
  end
  
  def subscribe_realtime
    Social::GatewayFacebookWorker.perform_async(page_id: page_id, action: 'create')
  end

  def remove_gateway_page_subscription
    Social::GatewayFacebookWorker.perform_async(page_id: page_id, action: 'destroy')
  end

  # Unsubscribing the realtime feed and pushing into the sidekiq
  def unregister_stream_subscription
    # Delete entries from dynamo here true means pushing to sidekiq
    cleanup(true)
  end

  def unsubscribe_realtime
    Facebook::PageTab::Configure.new(self).execute("unsubscribe_realtime")
  end

  def fetch_fb_wall_posts
    Social::FacebookDelta.perform_async({ :page_id => self.page_id }) if fetch_delta?
    Social::GatewayFacebookWorker.perform_async(page_id: page_id, action: 'update') if page_token_changed?
    check_and_remove_euc_pages if page_token_changed?
  end

  def check_and_remove_euc_pages
    return unless Account.current.launched?(:migrate_euc_pages_to_us)

    key = format(MIGRATE_EUC_FB_PAGES, account_id: Account.current.id)
    if remove_member_from_redis_set(key, page_id)
      remaining_pages = get_all_members_in_a_redis_set(key)
      Rails.logger.info("Found EUC Page #{page_id} and remaining pages are #{remaining_pages.inspect}")
    end
  end

  def send_mixpanel_event
    ::MixpanelWrapper.send_to_mixpanel(self.class.name)
  end

  def save_deleted_page_info
    @deleted_model_info = as_api_response(:central_publish)
  end

  def create_model_changes
    @model_changes = self.changes.to_hash
    @model_changes.symbolize_keys!
  end

  def can_central_publish?
    @model_changes.except(:message_since, :fetch_since).present?
  end
end

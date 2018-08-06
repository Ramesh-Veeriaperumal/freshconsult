class Social::TwitterHandle < ActiveRecord::Base
  include Cache::Memcache::Twitter
  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util
  include Social::SmartFilter
  include Redis::OthersRedis

  before_save :add_default_search, :set_default_state, :persist_previous_changes
  before_create :set_default_threaded_time
  after_commit :clear_cache
  after_commit :construct_avatar, :populate_streams, on: :create
  after_commit :cleanup, on: :destroy

  after_commit ->(obj) { obj.clear_handles_cache }, on: :create
  after_commit ->(obj) { obj.clear_handles_cache }, on: :destroy  
  after_commit :initialise_smart_filter, :on => :update, :if => :new_smart_filter_enabled?
  after_commit :remove_euc_redis_key, :on => :update, :if => :destroy_euc_redis_key?
  after_commit :remove_from_eu_redis_set_on_destroy, :on => :destroy, :if => :euc_migrated_account?
  before_destroy :save_deleted_handle_info

  def remove_from_eu_redis_set_on_destroy
    remove_euc_redis_key
  end

  def construct_avatar
    args = {
      :account_id        => self.account_id,
      :twitter_handle_id => self.id
    }
    Social::UploadAvatar.perform_async(args) unless Rails.env.test?
  end

  def populate_streams
    if account.active?
      build_default_streams
    end
  end

  def build_default_streams
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      default_stream_includes = [formatted_handle, "#{TWITTER_RULE_OPERATOR[:from]}#{self.screen_name}"] 
      build_stream(formatted_handle, TWITTER_STREAM_TYPE[:default], true, default_stream_includes)
      build_stream(screen_name, TWITTER_STREAM_TYPE[:dm], false, screen_name.dup)
    else
      error_params = {
        :twitter_handle_id => id,
        :account_id        => account_id,
        :stream            => def_stream.inspect
      }
      notify_social_dev("Default Stream already present for the handle", error_params)
    end
  end

  def cleanup
    streams = twitter_streams
    streams.each do |stream|
      if stream.data[:kind] != TWITTER_STREAM_TYPE[:custom]
        stream.destroy
      else
        stream.social_id = nil
        stream.save
      end
    end
  end

  def previous_changes
    @custom_previous_changes || HashWithIndifferentAccess.new
  end

  private
    def add_default_search
      if search_keys.blank?
        self.search_keys = []
      end
      self.search_keys.push(formatted_handle) unless search_keys.include?(formatted_handle)
    end

    def set_default_state
      self.state ||= TWITTER_STATE_KEYS_BY_TOKEN[:active]
    end

    # default value set for the column is '0'. To avoid db migration, setting at the callback level. Might change later
    def set_default_threaded_time
      self.dm_thread_time = DM_THREADTIME_KEYS_BY_TOKEN[:day]
    end

    def build_custom_streams
      search_keys.each do |search_key|
        build_stream(search_key, TWITTER_STREAM_TYPE[:custom], false, search_key) unless search_key == formatted_handle
      end
    end

    def build_stream(name, type, subscription, search_keys)
      stream_params = construct_stream_params(name, type, subscription, search_keys)
      stream = twitter_streams.build(stream_params)
      if stream.save && type == TWITTER_STREAM_TYPE[:default]
        Social::CustomTwitterWorker.perform_async({:stream_id => stream.id})
      end
      stream
    end

    def persist_previous_changes
      @custom_previous_changes = changes
    end

     def construct_stream_params(name, type, subscription, search_keys)
      stream_params = {
        :name     => name,
        :includes => search_keys.to_a,
        :excludes => [],
        :filter   => {
          :exclude_twitter_handles => []
        },
        :data => {
          :kind => type,
          :gnip => subscription
        }
      }
      stream_params.merge!({:accessible_attributes => {
          :access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        }}) if type == TWITTER_STREAM_TYPE[:default]
      stream_params
    end

    def smart_filter_init_params
      {
        "account_id" => smart_filter_accountID(:twitter, self.account_id, self.twitter_user_id)
      }.to_json
    end

    def initialise_smart_filter
      Social::SmartFilterInitWorker.perform_async({:smart_filter_init_params => smart_filter_init_params})
    end

    def new_smart_filter_enabled?
      @custom_previous_changes[:smart_filter_enabled] && @custom_previous_changes[:smart_filter_enabled][0].nil? && @custom_previous_changes[:smart_filter_enabled][1]
    end

    def destroy_euc_redis_key?
      # When the consumer authorizes the new app access_token will change and when they re-authorize the state will change.
      euc_migrated_account? && (self.previous_changes["state"].present? || self.previous_changes["access_token"].present?)
    end

    def euc_migrated_account?
      Account.current.euc_migrated_twitter_enabled?
    end

    def remove_euc_redis_key
      twitter_handle_id = self.twitter_user_id

      if remove_member_from_redis_set(EU_TWITTER_HANDLES, "#{Account.current.id}:#{twitter_handle_id}")
        Rails.logger.debug "Removed the twitter handle ID from the EU redis key, Account ID: #{Account.current.id}, Handle ID: #{twitter_handle_id}"
      end
    end

    def save_deleted_handle_info
      @deleted_model_info = as_api_response(:central_publish)
    end
end

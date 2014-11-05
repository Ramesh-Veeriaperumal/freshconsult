class Social::TwitterHandle < ActiveRecord::Base
  include Cache::Memcache::Twitter
  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util

  before_save :add_default_search, :set_default_state, :persist_previous_changes
  before_create :set_default_threaded_time
  after_commit :clear_cache
  after_commit :construct_avatar, :populate_streams, on: :create
  after_commit :cleanup, on: :destroy

  after_commit ->(obj) { obj.clear_handles_cache }, on: :create
  after_commit ->(obj) { obj.clear_handles_cache }, on: :destroy  

  def construct_avatar
    args = {
      :account_id        => self.account_id,
      :twitter_handle_id => self.id
    }
    Resque.enqueue(Social::Workers::Twitter::UploadAvatar, args) unless Rails.env.test?
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
      build_stream(formatted_handle, STREAM_TYPE[:default], true, default_stream_includes)
      build_stream(screen_name, STREAM_TYPE[:dm], false, screen_name.dup)
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
      if stream.data[:kind] != STREAM_TYPE[:custom]
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
        build_stream(search_key, STREAM_TYPE[:custom], false, search_key) unless search_key == formatted_handle
      end
    end

    def build_stream(name, type, subscription, search_keys)
      stream = twitter_streams.build(
        :name     => name,
        :includes => search_keys.to_a,
        :excludes => [],
        :filter   => {
          :exclude_twitter_handles => []
        },
        :data => {
          :kind => type,
          :gnip => subscription
        })
      if stream.save && type == STREAM_TYPE[:default]
        args_hash = {
          :account_id => account.id, 
          :insert_dynamo => true, 
          :stream_id => stream.id 
        }
        Resque.enqueue(Social::Workers::Stream::Twitter, args_hash)
      end
      stream
    end

    def persist_previous_changes
      @custom_previous_changes = changes
    end

end

class Social::TwitterHandle < ActiveRecord::Base
  include Cache::Memcache::Twitter
  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util

  before_save :set_default_state, :add_default_search
  #before_create :set_default_threaded_time
  before_update :cache_old_model
  after_commit_on_create :construct_avatar, :subscribe_to_gnip
  after_commit_on_update :update_streams, :update_ticket_rules
  after_commit_on_destroy :cleanup
  after_commit :clear_cache


  def construct_avatar
    args = {:account_id => self.account_id,
            :twitter_handle_id => self.id}
    Resque.enqueue(Social::Workers::Twitter::UploadAvatar, args) unless Rails.env.test?
  end

  def gnip_rule
    {
      :value => "#{formatted_handle}",
      :tag => deprecated_rule_tag
    }
  end

  def subscribe_to_gnip
    args = {
      :account_id => self.account_id,
      :env => gnip_envs({:subscribe => true}),
      :rule => gnip_rule,
      :action => RULE_ACTION[:add]
    }
    Resque.enqueue(Social::Workers::Gnip::TwitterRule, args) unless valid_params?(args)
  end

  def build_default_streams
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      default_stream_includes = [formatted_handle, "#{TWITTER_RULE_OPERATOR[:from]}#{self.screen_name}"]
      build_stream(formatted_handle, STREAM_TYPE[:default], true, default_stream_includes)
      build_stream(screen_name, STREAM_TYPE[:dm], false, screen_name)
    else
      error_params = {
        :twitter_handle_id => id,
        :account_id        => account_id,
        :stream            => def_stream.inspect
      }
      notify_social_dev("Default Stream already present for the handle", error_params)
    end
  end

  def build_custom_streams
    search_keys.each do |search_key|
      build_stream(search_key, STREAM_TYPE[:custom], false, search_key) unless search_key == formatted_handle
    end
  end

  def update_ticket_rules
    streams = self.twitter_streams
    unless streams.empty?
      default_stream = self.default_stream
      if @old_handle.capture_mention_as_ticket && !capture_mention_as_ticket
        default_stream.ticket_rules.first.destroy unless (default_stream.ticket_rules.empty?)
      elsif !@old_handle.capture_mention_as_ticket && capture_mention_as_ticket
        default_stream.populate_ticket_rule(nil, [formatted_handle])
      end

      dm_stream = self.dm_stream
      if @old_handle.capture_dm_as_ticket && !capture_dm_as_ticket
        dm_stream.ticket_rules.first.destroy unless (dm_stream.ticket_rules.empty?)
      elsif !@old_handle.capture_dm_as_ticket && capture_dm_as_ticket
        dm_stream.populate_ticket_rule(nil, includes)
      end

    else # TODO REMOVE AFTER MIGRATION
      if @old_handle.capture_mention_as_ticket && !capture_mention_as_ticket
        cleanup
      elsif !@old_handle.capture_mention_as_ticket && capture_mention_as_ticket
        subscribe_to_gnip
      end
    end
  end

  def cleanup # @ARV@ TODO change after migration
    if self.twitter_streams.blank?
      envs = STREAM.values
      args = {
        :account_id => self.account_id,
        :env => envs,
        :rule => gnip_rule,
        :action => RULE_ACTION[:delete]
      }
      Resque.enqueue(Social::Workers::Gnip::TwitterRule, args) unless valid_params?(args)
    end

    streams = self.twitter_streams
    streams.each do |stream|
      stream.destroy
    end
  end



  private
    def cache_old_model
      @old_handle = Social::TwitterHandle.find id
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
      stream.save
    end


    def add_default_search
      if search_keys.blank?
        searches = Array.new
        searches.push(formatted_handle)
        self.search_keys = searches
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

    def update_streams
      streams = self.twitter_streams
      unless streams.empty?
        #Can Change to one custom stream, now multiple streams
        old_search_keys = @old_handle.search_keys

        remove_keywords = old_search_keys - search_keys
        remove_keywords.each do |remove_keyword|
          stream = find_custom_stream(remove_keyword)
          stream.destroy unless stream.nil?
        end

        add_keywords = search_keys - old_search_keys
        add_keywords.each do |add_keyword|
          build_stream(add_keyword, STREAM_TYPE[:custom], false, add_keyword)
        end
      end
    end

    def gnip_envs(options = {}) # @ARV@ TODO REMOVE_AFTER_MIGRATION
      gnip_state = self.gnip_rule_state
      case gnip_state
      when GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
        streams = options[:subscribe] ? [STREAM[:replay], STREAM[:production]] : []
      when GNIP_RULE_STATES_KEYS_BY_TOKEN[:production]
        streams = options[:subscribe] ? [STREAM[:replay]] : [STREAM[:production]]
      when GNIP_RULE_STATES_KEYS_BY_TOKEN[:replay]
        streams = options[:subscribe] ? [STREAM[:production]] : [STREAM[:replay]]
      when GNIP_RULE_STATES_KEYS_BY_TOKEN[:both]
        streams = options[:subscribe] ? [] : [STREAM[:replay],STREAM[:production]]
      else
        streams = []
        params = {
          :id => self.id,
          :screen_name => self.screen_name,
          :account_id => self.account_id,
          :gnip_rule_state => self.gnip_rule_state
        }
        notify_social_dev("Invalid rule state for handle", params)
      end
      streams
    end

    def deprecated_rule_tag #TODO REMOVE MIGRATION
      "#{self.id}#{DELIMITER[:tag_elements]}#{self.account_id}"
    end

    def valid_params?(args)
      args[:env].blank? || args[:rule][:tag].nil? || args[:rule][:value].nil?
    end

end

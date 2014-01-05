class Social::TwitterHandle < ActiveRecord::Base
  include Cache::Memcache::Twitter
  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util

  before_save :set_default_state, :add_default_search
  before_update :cache_old_model
  after_commit_on_create :construct_avatar, :subscribe_to_gnip
  after_commit_on_update :update_streams, :update_ticket_rules
  after_commit_on_destroy :cleanup
  after_commit :clear_cache


  def construct_avatar
    args = {:account_id => self.account_id,
            :twitter_handle_id => self.id}
    Resque.enqueue(Social::Twitter::Workers::UploadAvatar, args) unless Rails.env.test?
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
    Resque.enqueue(Social::Twitter::Workers::Gnip, args) unless valid_params?(args)
  end

  def populate_default_stream
    def_stream = default_stream
    if def_stream.frozen? || def_stream.nil?
      stream = self.twitter_streams.build(
        :includes => search_keys,
        :data => {
          :kind => STREAM_TYPE[:default]
        })
      stream.save
    else
      error_params = {
        :twitter_handle_id => self.id,
        :account_id => self.account_id,
        :stream => def_stream.inspect
      }
      notify_social_dev("Default Stream already present for the handle", error_params)
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
      Resque.enqueue(Social::Twitter::Workers::Gnip, args) unless valid_params?(args)
    end

    #Delete the 'default' stream associated with this handle and
    #set social_id to nil for the remaining associated streams
    streams = self.twitter_streams
    streams.each do |stream|
      if stream.data[:kind] == STREAM_TYPE[:default]
        stream.destroy
      else
        stream.social_id = nil
        stream.save
      end
    end
  end


  private

    def cache_old_model
      @old_handle = Social::TwitterHandle.find id
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

    def update_streams
      stream = default_stream
      unless stream.nil?
        old_search_keys = @old_handle.search_keys
        unless ((old_search_keys - search_keys) + (search_keys - old_search_keys)).empty?
          stream.update_attributes(:includes => search_keys)
        end
      end
    end

    def update_ticket_rules
      stream = default_stream
      unless stream.nil?
        if @old_handle.capture_mention_as_ticket && !capture_mention_as_ticket
          tkt_rules = stream.ticket_rules
          tkt_rules.first.destroy # which rule to delete? Deleting first rule now
        elsif !@old_handle.capture_mention_as_ticket && capture_mention_as_ticket
          stream.populate_ticket_rule([formatted_handle])
        end
      else # TODO REMOVE AFTER MIGRATION
        if @old_handle.capture_mention_as_ticket && !capture_mention_as_ticket
          cleanup
        elsif !@old_handle.capture_mention_as_ticket && capture_mention_as_ticket
          subscribe_to_gnip
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

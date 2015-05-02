class Social::TwitterStream < Social::Stream

  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util

  before_create :set_default_values
  before_validation :valid_rule?, :if => :gnip_subscription?
  before_save :update_rule_value, :unless => :gnip_subscription?
  before_save :persist_previous_changes
  after_commit :subscribe_to_gnip, on: :create, :if => :gnip_subscription?
  after_commit :populate_ticket_rule, on: :create
  after_commit :update_gnip_subscription, on: :update, :if => :gnip_subscription?
  after_commit :unsubscribe_from_gnip, on: :destroy, :if =>  :gnip_subscription?
  after_commit :clear_volume_in_redis, on: :destroy


  def gnip_rule
    gnip_rule = {
      :value => rule_value,
      :tag   => rule_tag
    }
  end

  def clear_volume_in_redis
    newrelic_begin_rescue { $redis_others.del(stream_volume_redis_key) }
  end

  def previous_changes
    @custom_previous_changes || HashWithIndifferentAccess.new
  end
  
  def gnip_subscription?
    self.data[:gnip] == true
  end
  
  def construct_unsubscribe_args(rule_value)
    rule = gnip_rule
    rule[:value] = rule_value unless rule_value.nil?
    envs = STREAM.values
    args = {
      :account_id => self.account_id,
      :rule       => rule,
      :env        => envs,
      :action     => RULE_ACTION[:delete]
    }
  end

  private
    def set_default_values
      self.data[:gnip]            ||= false
      self.data[:gnip_rule_state] ||= GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
      self.data[:rule_value]      ||= nil
      self.data[:rule_tag]        ||= nil
      self.includes = [] if includes.blank?
      self.excludes = [] if excludes.blank?
      self.filter   = {:exclude_twitter_handles => []} if filter.blank?
    end

    def persist_previous_changes
      @custom_previous_changes = changes
    end

    def subscribe_to_gnip(environments=nil)
      envs = environments.nil? ? gnip_envs({:subscribe => true}) : environments
      if self.account.active?
        args = {
          :account_id => account_id,
          :rule       => gnip_rule,
          :env        => envs,
          :action     => RULE_ACTION[:add]
        }
        Resque.enqueue(Social::Workers::Gnip::TwitterRule, args) if valid_params?(args)
      end
    end

    def valid_rule?
      GnipRule::Rule.new(rule_value, rule_tag).valid?
    end

    def update_gnip_subscription
      if rule_value_changed?
        unsubscribe_from_gnip(data[:rule_value])
        subscribe_to_gnip(STREAM.values)
      end
    end

    def unsubscribe_from_gnip(rule_value=nil)
      args = construct_unsubscribe_args(rule_value)
      Resque.enqueue(Social::Workers::Gnip::TwitterRule, args) if valid_params?(args)
    end

    def update_rule_value
      query = Social::Twitter::Query.new(includes, excludes, filter[:exclude_twitter_handles])
      self.data[:rule_value] = query.query_string
    end

    def valid_params?(args)
      !(args[:env].blank? && args[:rule][:tag].nil? && args[:rule][:value].nil?)
    end

    def rule_value
      query = Social::Twitter::Query.new(includes, excludes, filter[:exclude_twitter_handles], RULE_OPERATOR[:ignore_rt])
      query.query_string
    end

    def rule_value_changed?
      !(previous_changes["includes"].nil? and previous_changes["excludes"].nil? and previous_changes["filter"].nil?)
    end

    def rule_tag
      "#{TAG_PREFIX}#{self.id}#{DELIMITER[:tag_elements]}#{self.account_id}"
    end

    def gnip_envs(options = {})
      gnip_state = data[:gnip_rule_state]
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
          :id         => self.id,
          :account_id => self.account_id,
          :data       => self.data
        }
        notify_social_dev("Invalid rule state for streams", params)
      end
      streams
    end
end

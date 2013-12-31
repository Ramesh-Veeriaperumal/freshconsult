class Social::TwitterStream < Social::Stream

  include Social::Twitter::Constants
  include Gnip::Constants
  include Social::Constants
  include Social::Util

  before_create :set_default_values
  before_update :cache_old_model
  after_commit_on_create :subscribe_to_gnip
  after_commit_on_update :update_gnip_subscription
  after_commit_on_destroy :unsubscribe_from_gnip


  def gnip_rule
    {:value => rule_value, :tag => rule_tag }
  end

  private
    def cache_old_model
      @old_stream = Social::TwitterStream.find id
    end

    def set_default_values
      self.description ||= STREAM_TYPE[:default]
      self.name ||= STREAM_TYPE[:default]
      self.data[:gnip_rule_state] ||= GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
      self.data[:rule_value] ||= nil
      self.data[:rule_tag] ||= nil
    end

    def update_gnip_subscription
      unless ((@old_stream.includes - includes) + (includes - @old_stream.includes)).empty?
        unsubscribe_from_gnip(@old_stream.data[:rule_value])
        #self.reload if Rails.env.test? #Resque is run inline in test environment so need to reload 'self'
        subscribe_to_gnip([STREAM[:replay], STREAM[:production]])
      end
    end

    def subscribe_to_gnip(environments=nil)
      envs = environments.nil? ? gnip_envs({:subscribe => true}) : environments
      if self.account.active?
        args = {
          :account_id => self.account_id,
          :rule => gnip_rule,
          :env => envs,
          :action => RULE_ACTION[:add]
        }
        Resque.enqueue(Social::Twitter::Workers::Gnip, args) unless valid_params?(args)
      end
    end

    def unsubscribe_from_gnip(rule_value=nil)
      rule = gnip_rule
      rule[:value] = rule_value unless rule_value.nil?
      envs = STREAM.values
      args = {
        :account_id => self.account_id,
        :rule => rule,
        :env => envs,
        :action => RULE_ACTION[:delete]
      }
      Resque.enqueue(Social::Twitter::Workers::Gnip, args) unless valid_params?(args)
    end

    def valid_params?(args)
      args[:env].blank? || args[:rule][:tag].nil? || args[:rule][:value].nil?
    end

    def rule_value
      self.includes.join(RULE_OPERATOR[:or])
    end

    def rule_tag
      "#{TAG_PREFIX}#{self.id}#{DELIMITER[:tag_elements]}#{self.account_id}"
    end

    def gnip_envs(options = {})
      gnip_state = self.data[:gnip_rule_state]
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
          :account_id => self.account_id,
          :data => self.data
        }
        notify_social_dev("Invalid rule state for streams", params)
      end
      streams
    end
end

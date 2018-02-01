class Social::TwitterStream < Social::Stream

  include Social::Twitter::Constants
  include Social::Constants
  include Social::Util
  include Redis::RedisKeys
  include Social::SmartFilter

  concerned_with :callbacks

  belongs_to :twitter_handle,
    :foreign_key => :social_id,
    :class_name  => 'Social::TwitterHandle'

  has_one :smart_filter_rule,
    :class_name  => 'Social::TicketRule',
    :foreign_key => :stream_id,
    :dependent   => :destroy,
    :conditions  => {:rule_type => SMART_FILTER_RULE_TYPE }

  validates_presence_of :includes

  def check_ticket_rules(tweet_body)
    hash = {
      :stream_id => self.id
    }
    tkt_rules = self.ticket_rules
    tkt_rules.each do |rule|
      if rule.rule_type.blank? and rule.apply(tweet_body)
        hash.merge!({
          :convert    => true,
          :group_id   => rule.action_data[:group_id],
          :product_id => rule.action_data[:product_id]
        })
        break
      end
    end
    return hash
  end

  def check_smart_filter(tweet_body, tweet_id, twitter_user_id)
    hash = {
      :stream_id => self.id,
      :tweet => true
    }
    if is_english?(tweet_body)
      smart_filter_params = construct_smart_filter_params(tweet_body, tweet_id, twitter_user_id)
      can_convert_to_ticket = smart_filter_query(smart_filter_params)
      if can_convert_to_ticket == SMART_FILTER_DETECTED_AS_TICKET
        rule = smart_filter_rule #FOR NOW. WE NEED TO CHANGE THIS
        hash.merge!({
           :convert    => true,
           :smart_filter_response => SMART_FILTER_DETECTED_AS_TICKET,
           :group_id   => rule.action_data[:group_id],
           :product_id => rule.action_data[:product_id]
        })
      else 
        hash.merge!({
          :smart_filter_response => SMART_FILTER_DETECTED_AS_SPAM
        })
      end
    end
    hash
  end

  def construct_smart_filter_params(tweet_body, tweet_id, twitter_user_id)
    {
     :entity_id => tweet_id.to_s,
     :account_id => smart_filter_accountID(:twitter, Account.current.id, twitter_user_id),
     :text => tweet_body,
     :screen_name => [],
     :source => "twitter",
     :lang => "en"
    }.to_json
  end

  def populate_ticket_rule(group_id = nil, includes = [])
    includes = [self.name] if (self.default_stream? and includes.empty?)
    return unless can_create_rule?
    ticket_rule = self.ticket_rules.create(
      :filter_data => {
        :includes => includes 
      },
      :action_data => {
        :product_id => twitter_handle.product_id,
        :group_id   => group(group_id)

      })
  end

  def new_ticket_rule
    @ticket_rule = self.ticket_rules.new
    @ticket_rule.action_data = {
      :product_id => nil,
      :group_id   => nil
    }
    @ticket_rule.filter_data = {
      :includes => []
    }
    @ticket_rule
  end

  def build_smart_rule(rule)
    group_id = rule[:group_id].to_i unless rule[:group_id].nil?
    product_id = twitter_handle.product_id
    rule_type = SMART_FILTER_RULE_TYPE
    smart_rule_params = {
      :rule_type => rule_type,
        :filter_data => {
          :includes => []
        },
        :action_data => {
          :product_id => product_id,
          :group_id   => group_id
        }
      }  
    smart_rule_params      
  end
  
  def product_id
    self.ticket_rules.first.action_data[:product_id] unless self.ticket_rules.empty?
  end

  def exclude_handles_to_s
    filter.blank? ? "" : filter.values.flatten.join(",")
  end

  def default_stream?
    self.data[:kind] == TWITTER_STREAM_TYPE[:default]
  end

  def custom_stream?
    self.data[:kind] == TWITTER_STREAM_TYPE[:custom]
  end

  def update_volume_in_redis
    hash_key = select_valid_date(Time.now)
    newrelic_begin_rescue do
      incr_value = $redis_others.perform_redis_op("hincrby", stream_volume_redis_key, hash_key, 1)
      if incr_value == 1
        stale_date = Time.now - STREAM_VOLUME_RETENION_PERIOD
        stale_key  = select_valid_date(stale_date)
        $redis_others.perform_redis_op("hdel", stream_volume_redis_key, stale_key)
      end
      raise_threshold_alert(incr_value, hash_key) if ((incr_value > MAX_FEEDS_THRESHOLD) && (incr_value % 100 == 0))
    end
  end

  def should_check_smart_filter?(convert_hash)
    !convert_hash[:convert] && Account.current.twitter_smart_filter_enabled? && self.default_stream? && self.twitter_handle.smart_filter_enabled?
  end

  private
    def can_create_rule?
      can_create_mention_rule? or can_create_dm_rule?
    end

    def can_create_mention_rule?
      self.twitter_handle.capture_mention_as_ticket if self.twitter_handle and default_stream?
    end

    def can_create_dm_rule?
      self.twitter_handle.capture_dm_as_ticket if self.twitter_handle and dm_stream?
    end

    def dm_stream?
      self.data[:kind] == TWITTER_STREAM_TYPE[:dm]
    end

    def group(group_id)
      group_id = (group_id == 0 ? nil : group_id)
      group_id = group_id || (twitter_handle.product ? twitter_handle.product.primary_email_config.group_id : nil )
    end

    def raise_threshold_alert(threshold_value, week)
      error_params = {
        :rule => {
         :value => self.data[:rule_value],
         :tag => self.data[:rule_tag]
        },
        :name => self.name,
        :threshold_week => week,
        :current_feeds_count => threshold_value,
        :stream_id => self.id,
        :account_id => self.account_id
      }
      notify_social_dev("Feeds Threshold value reached for the stream - #{self.name} in gnip", error_params)
    end
    
    def stream_volume_redis_key
      STREAM_VOLUME % { :account_id => Account.current.id, :stream_id => self.id }
    end
end

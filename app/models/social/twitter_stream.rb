class Social::TwitterStream < Social::Stream

  include Social::Twitter::Constants
  include Social::Constants
  include Social::Util
  include Redis::RedisKeys

  concerned_with :callbacks

  belongs_to :twitter_handle,
    :foreign_key => :social_id,
    :class_name  => 'Social::TwitterHandle'

  validates_presence_of :includes

  def check_ticket_rules(tweet_body)
    hash = {
      :stream_id => self.id
    }
    tkt_rules = self.ticket_rules
    tkt_rules.each do |rule|
      if rule.apply(tweet_body)
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

module Redis::AutomationRuleRedis
  include Redis::Keys::AutomationRules

  def inc_automation_rule_exec_count(rule_id, incr_by = 1)
    rule_key = automation_rule_id(rule_id)
    incr_automation_redis_key_in_hash(account_automation_key, rule_key, incr_by)
  end

  def set_expiry_of_account_rule(expiry_time = 86400) # 1 day
    expiry_of_automation_hash = get_expiry_of_automation_hash(account_automation_key)
    return false if expiry_of_automation_hash.present? && expiry_of_automation_hash >= 0

    set_expiry_of_automation_hash(account_automation_key, expiry_time)
  end

  def get_multi_automation_key_values(rule_ids = [], options = {})
    get_multi_automation_redis_key_in_hash(account_automation_key(options), rule_ids.map { |id| automation_rule_id(id) })
  end

  def automation_rules_with_thank_you_configured
    format(AUTOMATION_RULES_WITH_THANK_YOU_CONFIGURED, { account_id: Account.current.id })
  end

  def add_element_to_automation_redis_set(redis_key, element)
    $redis_automation_rule.perform_redis_op('sadd', redis_key, element)
  end

  def remove_element_from_automation_redis_set(redis_key, element)
    $redis_automation_rule.perform_redis_op('srem', redis_key, element)
  end

  def get_members_from_automation_redis_set(redis_key)
    $redis_automation_rule.perform_redis_op('smembers', redis_key)
  end

  def delete_automation_redis_key(redis_key)
    newrelic_begin_rescue do
      $redis_automation_rule.perform_redis_op('del', redis_key)
    end
  end

  private

    def account_automation_key(options = {})
      current_time = Time.zone.now
      format(AUTOMATION_RULES_BY_DATE, { account_id: Account.current.id,
                                mm: (options[:month] || current_time.month),
                                dd: (options[:day] || current_time.day) })
    end

    def automation_rule_id(rule_id)
      format(AUTOMATION_RULE_ID, { rule_id: rule_id })
    end

    def automation_redis_key_exists?(key)
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('exists', key)
      end
    end

    def get_expiry_of_automation_hash(redis_key)
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('ttl', redis_key)
      end
    end

    def set_expiry_of_automation_hash(redis_key, expiry_time)
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('expire', redis_key, expiry_time)
      end
    end

    def set_redis_keys_in_automation_hash(redis_key, keys)
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('hmset', redis_key, keys)
      end
    end

    def incr_automation_redis_key_in_hash(redis_key, key, incr_by)
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('hincrby', redis_key, key, incr_by)
      end
    end

    def get_multi_automation_redis_key_in_hash(redis_key, keys)
      keys = *keys
      newrelic_begin_rescue do
        $redis_automation_rule.perform_redis_op('hmget', redis_key, keys)
      end
    end

    def automation_perform_in_redis_transaction
      newrelic_begin_rescue do
        $redis_automation_rule.multi do
          yield
        end
      end
    end

    def get_automation_redis_key(key)
      newrelic_begin_rescue { $redis_automation_rule.perform_redis_op('get', key) }
    end
end

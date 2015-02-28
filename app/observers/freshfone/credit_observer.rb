class Freshfone::CreditObserver < ActiveRecord::Observer
  observe Freshfone::Credit

  include Freshfone::NodeEvents
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Freshfone::CallsRedisMethods

  def after_credit_update(freshfone_credit)
    account = freshfone_credit.account
    return if account.freshfone_account.blank?
    update_freshfone_widget(freshfone_credit, account)
    update_freshfone_account_state(freshfone_credit, account)
    notify_low_balance(freshfone_credit, account)
    trigger_auto_recharge(freshfone_credit) if auto_recharge_threshold_reached?(freshfone_credit)
    freshfone_credit
  end

  private
    def notify_low_balance(freshfone_credit, account)
      if credit_limit_on_disabled_auto_recharge?(freshfone_credit, account)
        # notify_freshfone_admin_dashboard
        FreshfoneNotifier.low_balance(account, freshfone_credit.available_credit) 
      end
      reset_low_credit_account(account) if !freshfone_credit.recharge_alert?
    end

    def update_freshfone_account_state(freshfone_credit, account)
      if account.freshfone_account.suspended?
        restore_freshfone_account_state(freshfone_credit, account)
      elsif freshfone_credit.zero_balance?
        suspend_freshfone_account(account)
        FreshfoneNotifier.suspended_account(account)
      end
    end

    def suspend_freshfone_account(account)
      account.freshfone_account.suspend_with_expiry = true
      account.freshfone_account.suspend
    end

    def update_freshfone_widget(freshfone_credit, account)
      if !freshfone_credit.auto_recharge?
        if freshfone_credit.below_calling_threshold?
          publish_freshfone_widget_state(account, "disable")
          escalte_to_redis_previous_low(account)
        else
          publish_freshfone_widget_state(account, "enable") if recharged_after_threshold?(freshfone_credit, account)
        end
      end
    end

    def credit_limit_on_disabled_auto_recharge?(freshfone_credit, account)
      !freshfone_credit.auto_recharge? and 
      !freshfone_credit.freshfone_suspended? and
      freshfone_credit.recharge_alert? and
      first_time_notified?(account) 
    end

    def auto_recharge_threshold_reached?(freshfone_credit)
      freshfone_credit.auto_recharge? and
        freshfone_credit.auto_recharge_threshold_reached? and auto_recharge_throttle_limit_reached?(freshfone_credit.account_id)
    end

    def trigger_auto_recharge(freshfone_credit)
      # freshfone_credit.send_later(:perform_auto_recharge)
      set_integ_redis_key(autorecharge_key(freshfone_credit.account_id), "true", 1800) #Key will be expire in 30 mins
      Resque::enqueue(Freshfone::Jobs::AutoRecharge, {:id => freshfone_credit.id})
      Rails.logger.debug "Auto-Recharge triggered for account #{freshfone_credit.account_id}"
    end
    
    def restore_freshfone_account_state(freshfone_credit, account)
      return if freshfone_credit.zero_balance?
      if account.freshfone_account.restore
        restore_freshfone_numbers(account)
      end
    end

    def restore_freshfone_numbers(account)
      account.freshfone_numbers.expired.update_all(
              :state => Freshfone::Number::STATE[:active])
    end

    def recharged_after_threshold?(freshfone_credit, account)
     !freshfone_credit.below_calling_threshold? and previously_low?(account)
    end

    def previously_low?(account)
      remove_value_from_set('FRESHFONE_DISABLED_WIDGET_ACCOUNTS', account.id)
    end

    def first_time_notified?(account)
      add_to_set('FRESHFONE_LOW_CREDITS_NOTIFIY', account.id)
    end

    def escalte_to_redis_previous_low(account)
      add_to_set('FRESHFONE_DISABLED_WIDGET_ACCOUNTS', account.id)
    end

    def reset_low_credit_account(account)
      remove_value_from_set('FRESHFONE_LOW_CREDITS_NOTIFIY', account.id)
    end
end

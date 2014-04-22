class Freshfone::Jobs::UsageTrigger
  extend Resque::AroundPerform

  @queue = "freshfone_default_queue"

  def self.perform(args)
    return unless freshfone_account_active?

    @trigger_type = args[:trigger_type] 
    action = "ut_#{trigger_type}"
    send(action, args) if respond_to?(action)
    delete_trigger if args[:recurring].blank?
    Freshfone::UsageTrigger.create_trigger(Account.current, args)
  end

  private

    def self.freshfone_account_active?
      Account.current.freshfone_account && Account.current.freshfone_account.active?
    end

    def self.previous_usage_trigger
      @previous_trigger ||=
        Account.current.freshfone_account.freshfone_usage_triggers.previous(trigger_type).first
    end

    def self.trigger_type
      @trigger_type
    end

    def self.get_trigger(sid)
      Account.current.freshfone_subaccount.usage.triggers.get(sid) if sid.present?
    end

    def self.delete_trigger
      begin
        trigger = previous_usage_trigger
        get_trigger(trigger.sid).delete if trigger.present?
      rescue Exception => e
        NewRelic::Agent.notice_error(e, { :sid => sid })
        #puts "Error - #{e} \n #{e.backtrace.join("\n\t")}"
      end
    end

    def self.ut_credit_overdraft(args)
      topup_credit = args[:purchased_credit]
      trigger_value = args[:trigger_value]

      if topup_credit.present?
        available_credit = Account.current.freshfone_credit.available_credit
        if topup_credit > available_credit
          topup_credit = available_credit
        else
          topup_credit += previous_trigger_balance
        end
        trigger_value = topup_credit
      end

      #85% considering profit margin
      args[:trigger_value] = "+#{(trigger_value * 0.85).to_i}"
    end

    def self.previous_trigger_balance
      previous_balance = 0
      trigger = previous_usage_trigger
      return previous_balance if trigger.blank? || trigger.fired_value.present?

      begin
        trigger = get_trigger trigger.sid
        if trigger.present?
          trigger_value = trigger.trigger_value
          current_value = trigger.current_value
          previous_balance = trigger.trigger_value.to_i - trigger.current_value.to_i
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e, { :previous_balance => previous_balance })
        #puts "Error - #{e} \n #{e.backtrace.join("\n\t")}"
      end

      previous_balance
    end

end

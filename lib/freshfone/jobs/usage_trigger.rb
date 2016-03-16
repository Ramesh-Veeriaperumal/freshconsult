class Freshfone::Jobs::UsageTrigger
  extend Resque::AroundPerform

  @queue = "freshfone_default_queue"

  def self.perform(args)
    return unless freshfone_account_active_or_trial?

    return delete_usage_trigger(args) if args[:delete]
    @trigger_type = args[:trigger_type] 
    action = "ut_#{trigger_type}"
    send(action, args) if respond_to?(action)
    # delete_trigger if args[:recurring].blank? && Freshfone::UsageTrigger::TRIAL_TRIGGERS.exclude?(args[:trigger_type].to_sym)
    Freshfone::UsageTrigger.create_trigger(Account.current, args)
  end

  private

    def self.freshfone_account_active_or_trial?
      freshfone_account = ::Account.current.freshfone_account
      freshfone_account.active_or_trial?
    end

    def self.trigger_type
      @trigger_type
    end

    def self.get_trigger(sid)
      Account.current.freshfone_subaccount.usage.triggers.get(sid) if sid.present?
    end

    def self.delete_usage_trigger(args)
      return if args[:trigger_sid].blank?
      usage_trigger = get_trigger(args[:trigger_sid])
      usage_trigger.delete if usage_trigger.present?
    end

end

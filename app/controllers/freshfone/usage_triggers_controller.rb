class Freshfone::UsageTriggersController < FreshfoneBaseController

  before_filter :check_freshfone_account_state
  before_filter :load_trigger
  before_filter :check_duplicate

  attr_accessor :trigger

  def notify
    begin
      update_trigger
      @ops_notifier = Freshfone::OpsNotifier.new(current_account, 
        trigger.trigger_type)
      send trigger.trigger_type if respond_to?(trigger.trigger_type, true)
      @ops_notifier.alert_mail
    rescue Exception => e
      NewRelic::Agent.notice_error(e, params)
      #puts "Error - #{e} \n #{e.backtrace.join("\n\t")}"
    end

    head :ok
  end

  private

    def credit_overdraft
      if freshfone_account.active? && overdraft?
        # freshfone_account.suspend
        @alert_message = "SUSPEND FRESHFONE ACCOUNT. #{alert_message}"
      end
      @ops_notifier.message = @alert_message
    end

    def daily_credit_threshold
      @ops_notifier.alert_call
    end

    def overdraft?
      current_account.freshfone_credit.zero_balance? || 
        Freshfone::Payment.find(:first, :conditions => ["created_at > ? AND status = ?", 
          trigger.created_at, true]).blank?
    end

    def alert_message
      @alert_message ||= "Freshfone #{trigger.trigger_type} alert for account #{current_account.id}. 
        Available balance #{current_account.freshfone_credit.available_credit}."
    end

    def recurring?
      params[:Recurring].present?
    end

    def load_trigger
      @trigger ||= 
        freshfone_account.freshfone_usage_triggers.find_by_sid(params[:UsageTriggerSid])
      head :ok if trigger.blank?
    end

    def check_duplicate
      head :ok if trigger.idempotency_token == params[:IdempotencyToken]
    end

    def update_trigger
      if recurring? && trigger.idempotency_token.present?
        Freshfone::UsageTrigger.create(:freshfone_account => freshfone_account,
          :idempotency_token => params[:IdempotencyToken],
          :sid => trigger.sid,
          :trigger_type => trigger.trigger_type,
          :trigger_value => trigger.trigger_value,
          :fired_value => params[:CurrentValue].to_i)
      else
        trigger.update_trigger params
      end
    end

    def check_freshfone_account_state
      head :ok unless freshfone_account# || freshfone_account.suspended?
    end
    
end
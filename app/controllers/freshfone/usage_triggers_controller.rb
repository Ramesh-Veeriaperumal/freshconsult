class Freshfone::UsageTriggersController < FreshfoneBaseController

  before_filter :check_freshfone_account_state
  before_filter :check_second_level_for_whitelist
  before_filter :load_trigger
  before_filter :check_duplicate

  attr_accessor :trigger

  TRIGGERS = {
    :first_level => %w(alert_call),
    :second_level => %w(alert_call suspend_freshfone)
  }

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


    def daily_credit_threshold
      triggers = freshfone_account.triggers.invert
      level = triggers[trigger.trigger_value]
      actions = TRIGGERS[level] if level.present?
      second_level_message if level.present? && level == :second_level
      actions.each do |action|
        begin
          send action if respond_to?(action, true)
        rescue Exception => e
          Rails.logger.error "Error while performing #{action} for Account id #{freshfone_account.account.id} \n The Exception is #{e.message}\n"
        end
      end
    end

    def calls_inbound
      Rails.logger.info "Inbound Calls Limit Exceeded, for Account Id :: #{freshfone_account.account_id}"
      Rails.logger.info "Params :: #{params}"
      subscription.inbound_will_change!
      subscription.inbound_usage_exceeded!
    end

    def calls_outbound
      Rails.logger.info "Outbound Calls Limit Exceeded, for Account Id :: #{freshfone_account.account_id}"
      Rails.logger.info "Params :: #{params}"
      subscription.outbound_will_change!
      subscription.outbound_usage_exceeded!
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

    def alert_call
      @ops_notifier.alert_call
    end

    def suspend_freshfone
      freshfone_account.suspend
    end

    def subscription
      freshfone_account.subscription
    end

    def second_level_message
      @ops_notifier.message = "Freshfone #{trigger.trigger_type} alert for Account #{current_account.id}.\n 
      The Trigger Value is #{trigger.trigger_value} & The Current Value of the account is #{params[:CurrentValue]}"
    end

    def check_freshfone_account_state
      head :ok unless freshfone_account# || freshfone_account.suspended?
    end
    
    def check_second_level_for_whitelist
    	if freshfone_account.security_whitelist &&
    		freshfone_account.triggers[:second_level] == params[:TriggerValue].to_i
    		head :ok
    	end
    end
  end
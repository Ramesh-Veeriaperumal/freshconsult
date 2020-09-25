module Freshfone
  class TrialCallTriggerWorker < BaseWorker

    sidekiq_options :queue => :freshfone_trial_worker, :retry => 0, :failures => :exhausted

    def perform(args)
      Rails.logger.info 'Freshfone Trial Call Trigger Worker'
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "#{args.inspect}"

      args.symbolize_keys!
      return unless account_and_call_present? args
           
      remove_trial_trigger
      if minutes_left?
        add_new_trial_trigger
      else
        limit_type_exceeded!
      end
    rescue => e
      Rails.logger.error "Error Occurred in TrialTriggers Job For Account:: #{args[:account_id]} Call :: #{args[:call]}"
      Rails.logger.error "Exception Message :: #{e.message}\nException Stacktrace :: #{e.backtrace.join('\n\t')}"
      NewRelic::Agent.notice_error(e, {description: "Error in Trial Call Trigger Worker for Account:: #{args[:account_id]} Call :: #{args[:call]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
    ensure
      ::Account.reset_current_account
    end

    private

      def account_and_call_present?(args)
        @account = ::Account.current
        @call = @account.freshfone_calls.find args[:call] if @account.present?
        @account.present? && @call.present?
      end

      def remove_trial_trigger
        Freshfone::UsageTrigger.remove_calls_usage_triggers(@account.freshfone_account, [Freshfone::UsageTrigger::TRIGGER_TYPE[trigger_type]])
      end

      def add_new_trial_trigger
        Freshfone::UsageTrigger.create_trial_call_usage_trigger(trigger_type, @account.id, pending_minutes + twilio_calls_usage)
      end

      def minutes_left?
        pending_minutes > 0
      end

      def subscription
        @freshfone_subscription ||= @account.freshfone_subscription
      end

      def limit_type_exceeded!
        if @call.incoming?
          subscription.inbound_will_change!
          subscription.inbound_usage_exceeded!
        else
          subscription.outbound_will_change!
          subscription.outbound_usage_exceeded!
        end
      end

      def trigger_type
        @call.incoming? ? :calls_inbound : :calls_outbound
      end

      def twilio_calls_usage
        @account.freshfone_account.twilio_subaccount.usage.records.list(
          category: trigger_type.to_s.gsub('_', '-')).first.usage.to_i
      end

      def pending_minutes
        @call.incoming? ? subscription.pending_incoming_minutes : subscription.pending_outgoing_minutes
      end
  end
end

module Freshfone
  class DisconnectWorker < BaseWorker
    include Freshfone::Queue
    include Freshfone::Endpoints
    include Freshfone::FreshfoneUtil
    include Freshfone::Disconnect
    include Freshfone::Conference::Branches::RoundRobinHandler
    include Freshfone::SimultaneousCallHandler
    
    sidekiq_options queue: :freshfone_notifications, retry: 0,  failures: :exhausted

    attr_accessor :params, :agent, :current_account, :current_call, :current_number, 
      :freshfone_users, :available_agents, :busy_agents, :tid, :current_user

    def perform(params)
      params.symbolize_keys!
      self.params = params
      self.tid = Thread.current.object_id.to_s(36)
      log_worker_info
      self.current_account = ::Account.current

      return if invalid_params?
      self.current_user = current_account.users.technicians.visible.find(params[:agent])
      self.freshfone_users = current_account.freshfone_users
      errors = []
      ringing_calls.each do |call|
        begin
          next if call.meta.present? && !call.meta.agent_pinged_and_no_response?(params[:agent].to_i) && call.supervisor_controls.warm_transfer_initiated_calls.blank?
          self.current_call = call
          self.current_number = current_call.freshfone_number
          if simultaneous_call?
            move_call_to_queue
            next
          end
          initiate_disconnect
        rescue Exception => e
          log_error e
          errors << e
        end
      end
    rescue Exception => e
      log_error e
      notify_error e
      NewRelic::Agent.notice_error(e, {description: "Error in Disconnect Worker for account #{current_account.id} for User #{params[:agent]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
    ensure
      errors.each { |err| notify_error(err) }
      logger.info "[#{jid}] - [#{tid}] Job Completed"
    end

    private
      def ringing_calls
        current_account.freshfone_calls.calls_with_ids(params[:call_ids])
      end

      def log_worker_info
        logger.info "[#{jid}] - [#{tid}] Freshfone call queue worker"
        logger.info "[#{jid}] - [#{tid}] Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
        logger.info "[#{jid}] - [#{tid}] Params :: #{params.inspect}"
      end

      def log_error(exception)
        logger.error "[#{jid}] - [#{tid}] Exception Message :: #{exception.message}"
        logger.error "[#{jid}] - [#{tid}] Trace :: #{exception.backtrace.join('\n\t')}"
      end

      def invalid_params?
        [params[:agent], current_account].any?(&:blank?)
      end

      def notify_error(exception)
        FreshfoneNotifier.deliver_freshfone_ops_notifier(
          current_account,
          subject: "Disconnect Worker failure",
          message: "Account :: #{(current_account || {})[:id]} <br>
          Number Id :: #{(current_number || {})[:id]}<br>
          Number :: #{(current_number || {})[:number]}<br>
          Params :: #{params.inspect}<br>JID :: #{jid}<br>
          TID :: #{tid}<br>Exception Message :: #{exception.message} <br>
          Error Code :: #{exception.respond_to?(:code) ? exception.code : ''}<br>
          Trace :: #{exception.backtrace.join('\n\t')}<br>")
      end
  end
end

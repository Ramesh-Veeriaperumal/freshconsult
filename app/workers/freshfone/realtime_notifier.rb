module Freshfone
  class RealtimeNotifier < BaseWorker
    include Freshfone::FreshfoneUtil
    include Freshfone::CallerLookup
    include Freshfone::Endpoints
    include Freshfone::CallsRedisMethods
    include Mobile::Actions::Push_Notifier

    sidekiq_options :queue => :freshfone_notifications, :retry => 0, :failures => :exhausted

    attr_accessor :params, :agents, :current_account, :current_call, :current_number, :tid

    def perform(params, call_id, agents, type)
      begin
        self.tid = Thread.current.object_id.to_s(36)
        logger.info "[#{jid}] - [#{tid}] Freshfone realtime notifier - Start time :: #{Time.now.strftime('%H:%M:%S.%L')} - Params :: #{params.inspect} - Call: #{call_id} - Browser Agents : #{agents.inspect}"
        self.current_account = ::Account.current
        self.current_call = current_account.freshfone_calls.find call_id
        self.current_number = current_call.freshfone_number
        self.params = params
        self.agents = agents

        enqueued_at = params["enqueued_at"]
        if enqueued_at
          job_latency = Time.now - Time.parse(enqueued_at)
          logger.info "[#{jid}] - [#{tid}] RealtimeNotifier Job Latency is more than #{incoming_timeout} seconds for JID #{jid} TID #{tid}" if job_latency > job_latency_treshold
          return if job_latency > job_latency_treshold
        end

        case type
          when "browser"
            @type ||= "incoming"
          when "browser_transfer"
            @type ||= "transfer"
          when "round_robin"
            @type ||= "round_robin"
          when "cancel_other_agents"
            return cancel_other_agents
          when "complete_other_agents"
            return complete_other_agents
          when "browser_warm_transfer"
            @type ||= "warm_transfer"
        end

        set_sid
        enqueue_notification_recovery
        logger.info "Socket Notification pushed to SQS for account :: #{current_account.id} , call_id :: #{current_call.id} at #{Time.now}"
        $freshfone_call_notifier.send_message notification_params.to_json
        freshfone_notify_incoming_call(notification_params)

      rescue Exception => e
        logger.error "[#{jid}] - [#{tid}] Error notifying for account #{current_account.id} for type #{type}"
        logger.error "[#{jid}] - [#{tid}] Message:: #{e.message}"
        logger.error "[#{jid}] - [#{tid}] Trace :: #{e.backtrace.join('\n\t')}"
        NewRelic::Agent.notice_error(e, {description: "Error in Realtime Notifier for account #{current_account.id} for type #{type}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        notify_error(e)
      ensure
        enqueue_call_timeout_job if enqueue_timeout_job?
      end
    end

    private

      def enqueue_notification_recovery
        Resque.remove_delayed(Freshfone::NotificationFailureRecovery, {:account_id => current_account.id, :call_id => current_call.id}) # to handle round robin notification
        Resque.enqueue_at(incoming_timeout.seconds.from_now, Freshfone::NotificationFailureRecovery, {:account_id => current_account.id, :call_id => current_call.id }) if current_call.is_root?
      end

      def job_latency_treshold
        incoming_timeout>5 ? incoming_timeout.to_i - 5 :  incoming_timeout
      end

      def set_sid
        set_browser_sid(params["ConferenceSid"], current_call.call_sid)
      end

      def notification_params
        return notification_message.merge!(
            warm_transfer_call_id: params['warm_transfer_call_id']) if params['warm_transfer_call_id'].present?
        notification_message
      end

      def notification_message
        {
          notification_type: @type,
          account_id: current_account.id,
          call_id: current_call.id,
          agents: self.agents,
          created_at: current_call.created_at,
          number_id: current_call.freshfone_number_id,
          call_sid: current_call.call_sid,
          number: current_call.caller_number,
          ringing_duration: current_call.freshfone_number.ringing_duration,
          enqueued_time: epoch_time,
          domain: current_account.freshfone_account.host
        }
      end

      def cancel_other_agents
        params = {
          notification_type: "cancelled",
          call_sid: current_call.call_sid,
          call_id: current_call.id,
          agents: warm_transfer_agent || pinged_agents,
          account_id: current_account.id,
          enqueued_time: epoch_time
          }
        $freshfone_call_notifier.send_message params.to_json
      end

      def complete_other_agents
        puts "Complete other agents"
        params = {
          notification_type: "completed",
          call_sid: current_call.call_sid,
          call_id: current_call.id,
          agents: pinged_agents,
          account_id: current_account.id,
          enqueued_time: epoch_time
        }
        $freshfone_call_notifier.send_message params.to_json
      end

      def pinged_agents
        current_call.meta.pinged_agents.map {|agent| agent[:id]}.compact
      end

      def warm_transfer_agent
        return if self.params['warm_transfer_user_id'].blank?
        [self.params['warm_transfer_user_id']]
      end

      def epoch_time
        (Time.now.utc.to_f * 1000).to_i
      end

      def notify_error(exception)
        FreshfoneNotifier.deliver_freshfone_ops_notifier(
          current_account, subject: "RealtimeNotifier Failure",
          message: "Account :: #{(current_account || {})[:id]} <br>
          Call Id :: #{(current_call || {})[:id]}<br>
          Number Id :: #{(current_number || {})[:id]}<br>
          Number :: #{(current_number || {})[:number]}<br>
          Params :: #{params.inspect}<br>Agents :: #{agents.inspect}<br>
          JID :: #{jid}<br>TID :: #{tid}<br>
          Exception Message :: #{exception.message} <br>
          Error Code :: #{exception.respond_to?(:code) ? exception.code : ''}<br>
          Trace :: #{exception.backtrace.join('\n\t')}<br>")
      end

      def enqueue_timeout_job?
        ['incoming', 'transfer', 'round_robin', 'warm_transfer'].include?(@type)
      end

      def enqueue_call_timeout_job
        agents.each do |agent|
          worker_params = { account_id: current_account.id, agent: agent,
            call_id: current_call.id, CallStatus: 'no-answer' }
          Freshfone::CallTimeoutWorker.perform_in(ringing_timeout+5, worker_params)
        end
      end

      def ringing_timeout
        return current_call.freshfone_number.rr_timeout if @type == 'round_robin'
        current_call.freshfone_number.ringing_time
      end
  end
end

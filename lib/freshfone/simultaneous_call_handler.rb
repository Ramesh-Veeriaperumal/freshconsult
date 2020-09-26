module Freshfone
  module SimultaneousCallHandler
    include Freshfone::AgentsLoader

    private

      def move_call_to_queue
        log_simultaneous_call
        telephony.redirect_call(current_call.call_sid, simultaneous_call_queue_url)
      end

      def resolve_simultaneous_calls
        move_call_to_queue
        telephony.no_action
      end

      def log_simultaneous_call
        Rails.logger.debug "Call redirected to queue : Account : #{current_account.id} : agent : 
                            #{params[:agent] || params[:agent_id]} : call : #{current_call.call_sid}"
        Rails.logger.debug "Redirected call #{current_call.call_sid} :: #{busy_agents.map(&:id)}"
      end

      def simultaneous_call?
        self.current_number ||= current_call.freshfone_number
        load_agents(current_number)
        !transfer_call? && (all_agents_busy? || invalid_call?)
      end

      def all_agents_busy?
        (available_agents.empty? || agents_unavailable? ) && any_busy_agents? &&
          params[:CallStatus] == 'busy'
      end

      def invalid_call? # Edge case: To prevent incoming call for an agent with a call (bug #15531)
        return unless available_agents.one?
        user_id = available_agents.first.user_id
        current_account.freshfone_calls.agent_active_calls(user_id).present?
      end

      def agents_unavailable?
        available_agents.one? &&
          available_agents.first.user_id == params[:agent].to_i &&
          !params[:notification_type]
      end

      def any_busy_agents?
        agents_unavailable?
      end
  end
end
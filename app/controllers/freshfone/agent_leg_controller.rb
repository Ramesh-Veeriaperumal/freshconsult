module Freshfone
  class AgentLegController < ApplicationController
    include Freshfone::Queue
    include Freshfone::Endpoints
    include Freshfone::CallHistory
    include Freshfone::FreshfoneUtil
    include Freshfone::Disconnect
    include Freshfone::Conference::Branches::RoundRobinHandler
    include Freshfone::SimultaneousCallHandler

    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:disconnect_browser_agent, :remove_notification_recovery]
    before_filter :validate_request_from_node, :only => [:disconnect_browser_agent, :remove_notification_recovery]
    before_filter :validate_new_notifications_feature, only: [:disconnect_browser_agent, :agent_response]
    before_filter :load_ringing_calls, only: [:agent_response, :disconnect_browser_agent]

    attr_accessor :current_call, :current_number, :available_agents,
      :busy_agents, :freshfone_users

    MAX_CALL_LIMIT = 5

    def disconnect_browser_agent
      agent_response
    end

    def agent_response
      self.freshfone_users = current_account.freshfone_users
      ringing_calls.each do |call|
        begin
	        next if params[:call_ids].present? && call.meta.present? && !call.meta.agent_pinged_and_no_response?(params[:agent].to_i) 
          self.current_call = call
          self.current_number = call.freshfone_number
          if params[:agent_disconnected].blank? && simultaneous_call?
            move_call_to_queue
            next
          end
          initiate_disconnect
        rescue Exception => e
          logger.error "Exception Message :: #{e.message} For Call Id :: #{call.id} Account Id #{current_account.id} User Id:: #{current_user.id} , Trace :: #{e.backtrace.join('\n\t')}"
        end
      end
      render json: { status: :success }
    end

    def remove_notification_recovery
      render json: { status: :success } and return if remove_notification_failure_recovery(params[:account_id], params[:call_id])
    end  

    private

      def validate_request_from_node
        generated_hash = Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{params[:agent]}")
        valid_user = request.headers['HTTP_X_FRESHFONE_SESSION'] == generated_hash
        head :forbidden unless valid_user
      end

      def validate_new_notifications_feature
        return render json: { status: :failure } unless new_notifications?
      end

      def load_ringing_calls
        unless params[:call_ids] # when comes from disconnect_browser_agent
          params[:CallStatus] = 'busy' 
          @current_user = current_account.users.technicians.visible.find(params[:agent]) 
        end
        move_to_disconnect_worker if ringing_calls.count > MAX_CALL_LIMIT
        ringing_calls
      end

      def ringing_calls
        return @ringing_calls ||= current_account.freshfone_calls.calls_with_ids(params[:call_ids]) if params[:call_ids].present?
        @ringing_calls ||= current_account.freshfone_calls.ringing_calls
      end

      def move_to_disconnect_worker
        logger.info "Ringing Call Limit Check - Account ID : #{current_account.id} - Call Ids:#{params[:call_ids].inspect} Agent :: #{params[:agent]} Action :: #{params[:action]} 
        \n Moving Job to DisconnectWorker"
        jid = Freshfone::DisconnectWorker.perform_async(params)
        logger.info "Trigger Disconnect worker  JID :: #{jid}"
        return render json: { status: :success }
      end
  end
end

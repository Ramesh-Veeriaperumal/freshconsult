module Freshfone
  class AgentConferenceController < FreshfoneBaseController
    include Freshfone::CallHistory
    include Freshfone::FreshfoneUtil
    include Freshfone::Presence
    include Freshfone::CustomForwardingUtil
    include Freshfone::Endpoints

    before_filter :validate_agent_conference_request, only: [:add_agent]
    before_filter :create_agent_conference_call, only: [:add_agent]
    before_filter :validate_add_agent_success, only: [:success]
    before_filter :update_status, only: [:success]
    before_filter :handle_ignored_custom_forward, only: :status, if: :missed_custom_forward?
    before_filter :update_agent_conference_call, only: :status

    def add_agent
      notifier.notify_agent_conference(current_call, @agent_conference_call)
      render json: { status: :agent_ringing }
    end

    def success
      update_mobile_user_presence(Freshfone::User::PRESENCE[:busy])
      notifier.notify_agent_conference_status(current_call,'agent_conference_success')
      conf_params = { sid: current_call.ancestry.present? ? current_call.dial_call_sid : current_call.call_sid,
                      beep: false,
                      startConferenceOnEnter: false,
                      record: false,
                      endConferenceOnExit: false
                      }
      render xml: telephony.join_conference(conf_params)
    end

    def status
      update_mobile_user_presence
      notifier.notify_agent_conference_status(current_call,'agent_conference_completed',
                                       params[:CallStatus]) unless current_call.completed?
      empty_twiml
    end

    def cancel
      active_agent_conference_call = current_call.supervisor_controls
                                          .agent_conference_calls([Freshfone::SupervisorControl::CALL_STATUS_HASH[:default],
                                                                   Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing]])
      render json: { status: notify_cancel_agent_conference(active_agent_conference_call, current_call) }
    end

    def initiate_custom_forward
      render xml: telephony.custom_forwarding_response(current_call.agent_name,
        custom_agent_forwarding_url, current_call.freshfone_number.voice_type)
    end

    def process_custom_forward
      return handle_transfer_success if custom_forward_accept?
      return handle_ignored_transfer if custom_forward_reject?
      render_invalid_input(custom_agent_forwarding_url, current_call.agent_name)
    end

  private

    def validate_agent_conference_request
      return render json: { status: 'error' } unless agent_conference_preconditions
    end

    def agent_conference_preconditions
      agent_conference_enabled? && valid_target_agent? && valid_status?                                    
    end

    def agent_conference_enabled?
      current_account.features?(:agent_conference)
    end

    def valid_target_agent?
      params[:target].present? && current_account.users.find_by_id(params[:target])
                                                       .present?
    end

    def valid_status?
      return false if current_call.nil?
      current_call.can_add_agent?
    end

    def update_status
       agent_conference_call.update_status(Freshfone::SupervisorControl::CALL_STATUS_HASH[params[:CallStatus].to_sym])
    end

    def update_agent_conference_call
      agent_conference_call.update_details(CallDuration: params[:CallDuration],
                                    status: Freshfone::SupervisorControl::CALL_STATUS_HASH[params[:CallStatus].to_sym])
    end

    def create_agent_conference_call
      @agent_conference_call = current_call.supervisor_controls.create(
        supervisor: current_account.users.find(params[:target]),
        supervisor_control_type: Freshfone::SupervisorControl::CALL_TYPE_HASH[:agent_conference])
    end

    def agent_conference_call
      current_call.supervisor_controls.find(params[:add_agent_call_id])
    end

    def validate_add_agent_success
      return render json: { status: :error } unless current_call.ongoing?
    end

    def update_mobile_user_presence(status = nil)
      user = agent_conference_call.supervisor
      return unless user.available_on_phone?
      return update_freshfone_presence(user, status) if status.present?
      user.freshfone_user.reset_presence.save!
    end

    def notify_cancel_agent_conference(active_agent_conference_call, call)
      return :error unless active_agent_conference_call.present?
      notifier.cancel_agent_conference(active_agent_conference_call.first, call)
      :agent_conference_canceled
    end

    def notifier
      current_number = current_call.freshfone_number
      @notifier ||= Freshfone::Notifier.new(params, current_account,
                                            current_user, current_number)
    end

    def telephony
      current_number = current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account,
                                              current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:add_agent_call_id, :call])
      super
    end

    def custom_agent_forwarding_url
      forward_agent_conference_url(params[:call], params[:add_agent_call_id])
    end

    def handle_transfer_success
      update_status
      success
    end

    def handle_ignored_transfer
      agent_conference_call.update_status(Freshfone::SupervisorControl::
        CALL_STATUS_HASH[:busy]) unless agent_conference_call.busy?
      empty_twiml
    end

    def handle_ignored_custom_forward
      update_mobile_user_presence
      notifier.notify_agent_conference_status(
        current_call, 'agent_conference_unanswered')
      handle_ignored_transfer
    end

    def missed_custom_forward?
      custom_forwarding_enabled? && (agent_conference_call.busy? ||
        still_ringing?)
    end

    def still_ringing?
      agent_conference_call.ringing? && params[:CallStatus] == 'completed'
    end
  end
end

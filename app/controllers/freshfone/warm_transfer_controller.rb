module Freshfone
  class WarmTransferController < FreshfoneBaseController
    include Freshfone::Conference::TransferMethods
    include Freshfone::FreshfoneUtil
    include Freshfone::CallHistory
    include Freshfone::Endpoints
    include Freshfone::WarmTransferDisconnect
    include Freshfone::Presence
    include Freshfone::CustomForwardingUtil

    before_filter :select_current_call, only: [:initiate, :cancel, :resume, :warm_transfer_success]
    before_filter :validate_warm_transfer, only: [:initiate]
    before_filter :load_source_and_target_agent, only: [:initiate, :wait]
    before_filter :create_participation_leg, only: [:initiate]
    before_filter :clear_client_calls, only: [:initiate]
    before_filter :update_warm_transfer_leg, only: [:success]
    before_filter :publish_warm_transfer_state, only: [:success]
    before_filter :update_presence_to_busy, only: [:success], if: :user_available_on_phone?
    before_filter :update_queue_sid, only: [:wait]
    before_filter :update_agent_status, only: [:redirect_customer]
    before_filter :update_conference_sid, only: [:transfer_agent_wait]
    before_filter :validate_transfer_fallback_request, only: [:resume, :cancel]
    before_filter :update_inprogress_status, only: [:resume, :cancel]

    def initiate
      warm_transfer_notifier if current_call.onhold?
      initiate_hold(warm_transfer_hold_params) if current_call.inprogress?
      render json: { status: :initiated }
    end

    def wait
      warm_transfer_notifier
      render xml: telephony.play_hold_message
    end

    def success
      render xml: handle_warm_transfer_success
    end

    def transfer_agent_wait
      render xml: telephony.play_unhold_message
    end

    def redirect_source_agent
      render xml: telephony.join_conference(source_agent_conf_params)
    end

    def unhold
      redirect_warm_transfer_conference
      render json: { status: :unhold_initiated }
    end

    def join_agent
      telephony.redirect_call_to_conference(current_call.customer_sid,
                        redirect_customer_url(current_call.id)) if current_call.meta.warm_transfer_success?
      render xml: telephony.initiate_conference(agent_conf_params)
    end

    def redirect_customer
      render xml: telephony.join_conference(customer_conf_params)
    end

    def quit
      current_call.add_to_hold_duration(params[:QueueTime])
      render xml: telephony.no_action
    end

    def cancel
      active_warm_transfer_call = current_call.supervisor_controls
                                              .warm_transfer_initiated_calls.last
      update_canceled_warm_transfer(active_warm_transfer_call)
      notifier.cancel_warm_transfer(active_warm_transfer_call, current_call)
      telephony(current_call).initiate_transfer_fall_back
      notifier.notify_warm_transfer_status(current_call, :warm_transfer_cancel, params[:CallStatus])
      render json: { status: :unhold_initiated }
    end

    def resume
      telephony(current_call).initiate_transfer_fall_back
      notifier.notify_warm_transfer_status(current_call, :warm_transfer_resume)
      render json: { status: :unhold_initiated }
    end

    def initiate_custom_forward
      render xml: telephony.custom_forwarding_response(current_call.agent_name,
        custome_warm_transfer_url, current_call.freshfone_number.voice_type)
    end

    def process_custom_forward
      return handle_transfer_sucess if custom_forward_accept?
      return render xml: telephony.no_action if custom_forward_reject?
      render_invalid_input(custome_warm_transfer_url, current_call.agent_name)
    end

    private

    def validate_warm_transfer
      render json: { status: :error } unless warm_transfer_enabled? &&
                                            current_call.present? && current_call.ongoing?
    end

    def warm_transfer_hold_params
      { target: @target, source: @source, transfer_type: 'warm_transfer',
        call: current_call.id, warm_transfer_call_id: @supervisor_leg.id}
    end

    def redirect_warm_transfer_conference
      telephony.redirect_call_to_conference(current_call.customer_sid,redirect_customer_url(current_call.id))
    end

    def warm_transfer_notifier
      notifier.notify_warm_transfer(current_call, @target, @source, @supervisor_leg.id)
    end

    def publish_warm_transfer_state
      publish_active_call_end(current_call, current_account)
    end

    def load_source_and_target_agent
      @target = params[:group_id].present? ? params[:group_id] : params[:target]
      @source = params[:source].present? ? params[:source] : current_user.id
      @supervisor_leg = warm_transfer_leg if params[:warm_transfer_call_id].present?
    end

    def notifier
      @notifier ||= Freshfone::Notifier.new(params, current_account,
                                            current_user, current_call.freshfone_number)
    end

    def select_current_call
      @current_call = current_call.parent unless (current_call.inprogress? || current_call.onhold?)
    end

    def create_participation_leg
      @supervisor_leg = current_call.supervisor_controls.create(
        supervisor_id: @target,
        supervisor_control_type: Freshfone::SupervisorControl::CALL_TYPE_HASH[:warm_transfer])
    end

    def update_warm_transfer_leg
      warm_transfer_leg.update_details(sid: params[:CallSid],
        status: Freshfone::SupervisorControl::CALL_STATUS_HASH[:'in-progress'])
    end

    def update_presence_to_busy
      update_freshfone_presence(warm_transfer_user, Freshfone::User::PRESENCE[:busy])
    end

    def user_available_on_phone?
      warm_transfer_user.available_on_phone?
    end

    def warm_transfer_user
      @warm_transfer_user ||= warm_transfer_leg.supervisor
    end

    def update_canceled_warm_transfer(call)
      current_call.inprogress!
      create_child_call.update_call(DialCallStatus: 'canceled')
      call.update_details(
        status: Freshfone::SupervisorControl::CALL_STATUS_HASH[:canceled])
    end

    def update_queue_sid
      current_call.update_call_details(QueueSid: params[:QueueSid]).save
    end

    def transfer_leg
      agent_id = split_client_id(params[:To])
      transfer_leg = fetch_and_update_child_call(params[:call], params[:CallSid], agent_id)
    end

    def update_agent_status
      current_call.inprogress!
    end

    def source_agent_conf_params
      { sid: "#{warm_transfer_leg.sid}_warm_transfer", beep: true, endConferenceOnExit: false,
        record: false, startConferenceOnEnter: false }
    end

    def customer_conf_params
      { sid: current_call.agent_sid, beep: true, startConferenceOnEnter: true,
        endConferenceOnExit: false, record: 'record-from-start',
        recording_callback_url: recording_call_back_url }
    end

    def agent_conf_params
      { sid: current_call.agent_sid, startConferenceOnEnter: false, beep: true,
        endConferenceOnExit: true, wait_url: warm_transfer_agent_wait_url }
    end

    def validate_transfer_fallback_request
      return render json: { status: :error } unless current_call.present? &&
                                                        current_call.onhold?
    end

    def update_inprogress_status
      current_call.inprogress!
    end

    def validate_twilio_request
      @callback_params = params.except(*[:call, :hold_queue, :type, :transfer,
                                         :source, :target, :group_transfer,
                                         :transfer_type, :external_transfer,
                                         :warm_transfer_call_id])
      super
    end

    def custome_warm_transfer_url
      forward_warm_transfer_url(params[:warm_transfer_call_id], params[:call])
    end

    def handle_transfer_sucess
      update_warm_transfer_leg
      update_presence_to_busy
      success
    end
  end
end

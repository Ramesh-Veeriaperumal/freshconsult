class Freshfone::ConferenceCallController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::Presence
  include Freshfone::NumberMethods
  include Freshfone::Conference::EndCallActions
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods
  include Freshfone::SupervisorActions
  include Freshfone::AcwUtil
  
  before_filter :select_current_call, :only => [:status]
  before_filter :update_cancel_response, only: :status
  before_filter :complete_browser_leg, only: [:status], if: :agent_leg?
  before_filter :complete_supervisor_leg, :only => [:status], :if => :supervisor_leg?
  before_filter :check_conference_feature, :only => [:status]
  before_filter :handle_blocked_numbers, :only => [:status]
  before_filter :terminate_ivr_preview, :only => [:status]
  before_filter :validate_dial_call_status, :only => [ :status ]
  before_filter :update_agent_last_call_at, :only => [:status], :if => :outgoing_leg?
  before_filter :handle_direct_dial, :only => [:status]
  before_filter :populate_call_details, :only => [:status]
  before_filter :update_total_duration, :only => [:status]
  before_filter :update_agent, :only => [:in_call]
  before_filter :reset_outgoing_count, :only => [:status]
  before_filter :set_abandon_state, :only => [:status]
  before_filter :call_quality_monitoring_enabled?, :only => [:save_call_quality_metrics]
  before_filter :handle_invalid_details_save, only: :save_notable, unless: :valid_call_and_ticket?
  before_filter :validate_call_details_request, only: :load_notable

  def status
    begin
      complete_call
    rescue Exception => e
      notify_error({:ErrorUrl => e.message})
      return empty_twiml
    end
  end
  
  def in_call
    remove_batch_call_redis_entry
    params.merge!({:DialCallStatus => params[:CallStatus], :DialCallSid => params[:CallSid]})
    current_call.update_call(params)
    telephony.current_number = current_call.freshfone_number
      render :xml => telephony.initiate_agent_conference({
        :sid => current_call.call_sid,
        :wait_url => incoming_agent_wait_url })
  end

  def load_notable
    @call_id ||= get_call_id
    ticket_note = get_key(call_notable_key).to_s
    return render json: {call_notable: false } if ticket_note.blank?
    remove_key(call_notable_key)
    render json: {call_notable: JSON.parse(ticket_note) }
  end

  def save_notable
    @call_id ||= params[:call_id]
    ticket_note = set_key(call_notable_key,
                          { notes: params[:call_notes],
                            ticket: params[:ticket_details] }.to_json,
                          600) if params[:call_notes].present? || params[:ticket_details].present?
    render json: { data_set: ticket_note}
  end

  def save_call_quality_metrics
    render :json => {} and return if params[:call_id].blank? 
    render :json => {
      :call_quality_metrics_saved => set_key(call_quality_metrics_key(params[:call_id]), params[:call_quality_metrics].to_json , 259200) 
    }
  end

  def update_recording
    call_params = {
      :RecordingUrl => params[:RecordingUrl],
      :RecordingDuration => params[:Duration]
    }
    call = current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
    warm_transfer_call = call.supervisor_controls.inprogress_warm_transfer_calls.last if call.present?

    if call.present?
      call.set_call_duration(call_params, warm_transfer_call.blank?)
      call.update_call(call_params) 
    else
      Rails.logger.error "Unable to update recording for the conference #{params[:ConferenceSid]}"
    end
    return empty_twiml
  end

  def wrap_call
    return render :json => { :result => :failure } if current_call.blank?
    acw
    current_call.meta.update_feedback(params) if current_call.meta.present?
    render :json => { :result => true }
  end

  def acw
    return if !call_metrics_enabled? || phone_acw_enabled?
    current_call_leg = current_call.missed_child? ? current_call.parent : current_call
    current_call_leg.update_acw_duration
  end

  private
    def ongoing_call
      caller = current_account.freshfone_callers.find_by_number(params[:PhoneNumber])
      return if caller.blank?
      call = current_account.freshfone_calls.first( :conditions => {:caller_number_id => caller.id}, 
                :order => "freshfone_calls.id DESC")
    end

    def validate_dial_call_status
      if current_call.present?
        return if voicemail?
        return if current_call.direct_dial_number.present?
        return set_outgoing_status if single_leg_outgoing?
        return handle_agent_hunt_status if current_call.meta.present? && current_call.meta.agent_hunt?
        if current_call.agent.blank?
          params[:DialCallStatus] = "no-answer"
        else
          params[:DialCallStatus] = "completed"
        end
      end
    end

    def terminate_ivr_preview
      if current_call.blank? && ivr_preview?
        remove_ivr_preview
        add_preview_cost_job
        empty_twiml
      end
    end

    def handle_agent_hunt_status
      return if (current_call.missed_or_busy? || voicemail?)
      if current_call.ringing?
        params[:DialCallStatus] = "no-answer" 
      else
        params[:DialCallStatus] = "completed"
      end
    end

    def handle_direct_dial
      if current_call.present? && current_call.direct_dial_number   && current_call.dial_call_sid && current_call.ringing?
        agent_leg = current_account.freshfone_subaccount.calls.get(current_call.agent_sid)
        agent_leg.update(:status => "canceled")  
        set_abandon_state("no-answer")
        empty_twiml
      end
    end

    def validate_twilio_request
      @callback_params = params.except(*[:force_termination, :direct_dial_number, :conference_sid, :round_robin_call, :ParentCallSid, :forward_call, :call, :agent_id])
      super
    end

    def telephony
      current_number = current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number, current_call)
    end
    
    def conference_notifier
      @conference_notifier ||= Freshfone::Notifier.new(params, current_account,nil,current_number)
    end

    def populate_call_details
      key = ACTIVE_CALL % { :account_id => current_account.id, :call_sid => params[:CallSid]}
      @call_options = {}
      call_options = get_key key
      unless call_options.blank?
        @call_options = JSON.parse(call_options)
        params.merge!(@call_options)
        remove_key key
      end
    end

    def call_forwarded?
      @call_options["answered_on_mobile"] || params[:direct_dial_number]
    end

    def remove_batch_call_redis_entry
      key = FRESHFONE_AGENTS_BATCH % { :account_id => @current_account.id, :call_sid => current_call.call_sid }
      remove_key(key)
    end

    def update_agent
      @current_user ||= current_account.users.find_by_id(split_client_id(params[:To]))
      current_call.update_agent(@current_user) if current_call.agent.blank? && @current_user.present?
    end

    def current_number
      current_call.freshfone_number
    end

    def check_conference_feature
      return empty_twiml unless current_account.features?(:freshfone_conference)
    end

    def select_current_call
      return @current_call = participant_leg.call if current_call.blank? && participant_leg.present?
      return if current_call.blank?
      child_call = current_call.children.ongoing_or_completed_calls.last
      return @current_call = child_call if child_call.present? && child_call.meta.warm_transfer_meta?
      return if current_call.blank? || current_call.parent.blank?
      @current_call = current_call.parent if (current_call.parent.inprogress? || current_call.parent.onhold?)
      #Scenario: call hanged up after the use of cancel/resume functionality
    end

    def update_total_duration
      return if current_call.blank?
      if current_call.outgoing?
        call = current_call.root
        call.set_call_duration(params) if params[:call].blank? # update only for outgoing root calls
        call.save!
      elsif current_call.is_root? && current_call.is_childless?
        current_call.set_total_duration(params)
        current_call.save!
      end
    end

    def customer_leg_outgoing?
      single_leg_outgoing? && params[:call].present?
    end

    def voicemail?
      current_call.call_status == Freshfone::Call::CALL_STATUS_HASH[:voicemail]
    end

    def no_duration?
      params[:CallDuration].blank? || params[:CallSid].blank?
    end

    def reset_outgoing_count
      remove_device_from_outgoing(get_device_id) if current_call.present? && current_call.outgoing?
    end

    def get_device_id
      current_call.sip? ? sip_user : split_client_id(params[:From])
    end

    def handle_blocked_numbers
      render :xml => comment_twiml("Blocked Number") and return if current_call.present? && current_call.incoming? && current_call.blocked?
    end

    def set_outgoing_status
      if params[:call].present? && params[:CallStatus].present?
        params[:DialCallStatus] = params[:CallStatus] 
      else
        params[:DialCallStatus] = "no-answer" if current_call.default?
      end
    end

    def set_abandon_state(dial_call_status = params[:DialCallStatus])
      return unless current_call.present?
      call = current_call.get_abandon_call_leg
      dial_call_status = 'no-answer' if (!call.is_root? && call.ringing?)
      call_params =  params.merge({:DialCallStatus => dial_call_status}) # For handle_direct_dial 
      call.set_abandon_call(call_params)
    end

    def call_metrics_enabled?
      current_account.features?(:freshfone_call_metrics)
    end
   
    def call_quality_monitoring_enabled?
      render :json => {} unless current_account.features?(:call_quality_metrics)
    end

    def agent_leg?
      params[:From].present? && split_client_id(params[:From]).present? &&
        current_call.present? && (outgoing_child_leg? || warm_transfer_call_leg.present?)
    end

    def participant_leg
      current_account.supervisor_controls.where(sid: [params[:CallSid]]).last
    end

    def outgoing_child_leg?
      current_call.incoming? || (current_call.outgoing? && current_call.transferred_leg?)
    end

    def complete_browser_leg
      return if current_call.blank?
      set_agent
      render xml: agent_call_leg.initiate_disconnect
    end

    def handle_simultaneous_answer
      return if current_call.blank?
      freshfone_user = current_user.freshfone_user
      render json: { result: freshfone_user.reset_presence.save } if reset_preconditions?
    end

    def reset_preconditions?
      current_call.incoming? && (simultaneous_accept? ||
        simultaneous_canceled_transfer?)
    end

    #if two agents simultaneously accepted an incoming call, reset presence of
    #disconnected agent on closing end-call form
    def simultaneous_accept?
      current_call.user_id != current_user.id
    end

    #if agent transferring the call cancels the transfer at same moment when the other agent accepted the transferred
    #call, that agent will be stuck in busy state. reset presence on closing end-call form
    def simultaneous_canceled_transfer?
      current_call.ancestry.present? && current_call.canceled?
    end

    def handle_invalid_details_save
      render json: { data_saved: false }
    end

    def valid_call_and_ticket?
      current_account.freshfone_calls.where(id: params[:call_id]).present? &&
        ( params[:ticket_details].blank? ||
          current_account.tickets.visible.permissible(current_user).where(
            display_id: params[:ticket_details][:id]).present? )
    end

    def validate_call_details_request
      @call = ongoing_call
      return if @call.present? && (@call.ancestry.present? ||
        ongoing_supervisor_call.present?)
      render json: { data_available: false}
    end

    def ongoing_supervisor_call
      @suppervisor_call ||= @call.supervisor_controls.connecting_or_inprogress_calls.last
    end

    def get_call_id
      return @call.id if ongoing_supervisor_call.present?
      @call.parent.id
    end

    def update_cancel_response
      return if current_call.blank?
      call_meta = current_call.meta
      return unless current_call.ringing? && call_meta.present? &&
        (current_call.incoming? || current_call.transferred_leg?)
      call_meta.cancel_all_agents
    end
end

class Freshfone::ConferenceCallController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::Presence
  include Freshfone::NumberMethods
  include Freshfone::Conference::EndCallActions
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods
  
  before_filter :check_conference_feature, :only => [:status]
  before_filter :check_credit_balance, :only => [:status]
  before_filter :select_current_call, :only => [:status]
  before_filter :handle_blocked_numbers, :only => [:status]
  before_filter :terminate_ivr_preview, :only => [:status]
  before_filter :validate_dial_call_status, :only => [ :status ]
  before_filter :update_agent_last_call_at, :only => [:status], :if => :single_leg_outgoing?
  before_filter :handle_direct_dial, :only => [:status]
  before_filter :populate_call_details, :only => [:status]
  before_filter :update_total_duration, :only => [:status]
  before_filter :update_agent, :only => [:in_call]
  before_filter :reset_outgoing_count, :only => [:status]

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

  def call_notes
    call = ongoing_call
    if call.present? && call.ancestry.present?
      @call_sid ||= call.call_sid
      notes = CGI.unescapeHTML get_key(call_notes_key).to_s      
      remove_key(call_notes_key) unless notes.nil? 
      render :json => {:call_notes => notes}
    else
      render :json => {:call_notes => nil}
    end
  end

  def save_call_notes
    @call_sid ||= params[:call_sid]
    render :json => { 
      :notes_saved => set_key(call_notes_key, CGI.escapeHTML(params[:call_notes]) , 600)
    }
  end

  def update_recording
    call_params = {
      :RecordingUrl => params[:RecordingUrl],
      :RecordingDuration => params[:Duration]
    }
    call = current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
    if call.present?
      call.set_call_duration(call_params)
      call.update_call(call_params) 
    else
      Rails.logger.error "Unable to update recording for the conference #{params[:ConferenceSid]}"
    end
    return empty_twiml
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
        empty_twiml
      end
    end

    def validate_twilio_request
      @callback_params = params.except(*[:force_termination, :direct_dial_number, :conference_sid, :round_robin_call, :ParentCallSid, :forward_call, :call, :agent_id])
      super
    end

    def telephony
      current_number = current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
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

    def check_credit_balance
      render :xml => comment_twiml("Credits Below Threshold") and return if current_account.freshfone_credit.below_calling_threshold? 
    end

    def handle_blocked_numbers
      render :xml => comment_twiml("Blocked Number") and return if current_call.present? && current_call.incoming? && current_call.blocked?
    end

    def call_notes_key
      @call_notes_key ||= FRESHFONE_CALL_NOTE % { :account_id => @current_account.id, :call_sid => @call_sid }
    end

    def set_outgoing_status
      if params[:call].present? && params[:CallStatus].present?
        params[:DialCallStatus] = params[:CallStatus] 
      else
        params[:DialCallStatus] = "no-answer" if current_call.default?
      end
    end
end
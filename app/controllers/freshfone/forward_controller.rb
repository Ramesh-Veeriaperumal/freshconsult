class Freshfone::ForwardController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::NumberMethods
  include Freshfone::Presence
  include Freshfone::Queue
  include Freshfone::Endpoints
  include Freshfone::Conference::EndCallActions
  include Freshfone::CustomForwardingUtil

  before_filter :validate_trial, :if => :trial?
  before_filter :set_dial_call_sid, :only => [:complete, :direct_dial_accept]
  before_filter :update_conference_sid, :only => [:direct_dial_wait]
  before_filter :set_tranfer_call, :only => [:transfer_complete, :process_custom_transfer]
  before_filter :empty_twiml, only: :transfer_complete, if: :connected_to_other_agent?
  before_filter :update_agent_presence, :only => [:transfer_complete]
  before_filter :set_external_transfer_params, :only =>[:transfer_initiate]
  before_filter :handle_incomplete_call, only: :complete, if: :custom_ignored_call?
  before_filter :check_and_initiate_voicemail, :only => [:complete], :if => :voicemail_preconditions?
  before_filter :update_agent_last_call_at, :only => [:complete], :unless => :voicemail_preconditions?
  before_filter :transfer_ignored, :only => [:transfer_complete], :if => :check_transfer_ignored?
  before_filter :set_child_call_status, :only => [:transfer_initiate]
  before_filter :check_child_call_status, :only => [:transfer_complete]
  after_filter  :cancel_browser_agents, only: [:initiate, :process_custom], if: :new_notification_accepted_call?

  include Freshfone::Call::BranchDispatcher

  #Need to have begin-rescues here for all the methods


  def initiate
    params[:forward] = true
    agent_call_leg.current_call = current_call
    render :xml => agent_call_leg.process
  end

  def transfer_initiate
    parent_call = current_account.freshfone_calls.find(params[:call])
    notifier.notify_transfer_success(parent_call)
    update_call_meta_for_forward_calls parent_call.children.last if params[:external_transfer].blank?# updating call meta here as Params[:To] will be available here only.
    render :xml => transfer_leg.process_mobile_transfer
  end

  def transfer_wait
    current_call.update_call({:ConferenceSid => params[:ConferenceSid]})
    update_presence_and_publish_call({:agent => current_call.user_id}) if current_call.user_id.present? && current_call.direct_dial_number.blank? # for external transfer should not update user
    render :xml => telephony.play_agent_wait_music
  end

  def transfer_complete
    params[:DialCallStatus] = params[:CallStatus]
    @transferred_call.set_call_duration(params)
    @transferred_call.update_call(params)
    remove_conf_transfer_job(current_call)
    remove_value_from_set(pinged_agents_key(current_call.id), params[:CallSid])
    empty_twiml and return if @transferred_call.agent.blank?
    freshfone_user = @transferred_call.agent.freshfone_user 
    freshfone_user.set_last_call_at(Time.now)
    empty_twiml
  end

  def complete
    #Check AnsweredBy params and store the meta info for the agent in call meta
    #Test this: if anseredby is machine, the other agents should still be getting the call and should be able to accept the call
    remove_value_from_set(pinged_agents_key(current_call.id), params[:CallSid])
    return empty_twiml if ignored_call?
    current_call.set_call_duration(params)
    current_call.save!
    empty_twiml
  end

  def direct_dial_wait
    begin
      notifier.ivr_direct_dial(current_call)
      render :xml => telephony.play_wait_music
    rescue Exception => e
      #Any exception here is not going to stop the wait loop. so redirect the call to hangup
      Rails.logger.error "Error in conference incoming caller wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      empty_twiml
    end
  end

  def direct_dial_accept
    if current_call.present?
      create_or_update_call_meta current_call
      current_call.update_call(params)
      telephony.redirect_call_to_conference(params[:CallSid], direct_dial_connect_url(current_call.id))
    end
    empty_twiml
  end

  def direct_dial_connect #duplicate code in agent_call_leg
    telephony.current_number = current_call.freshfone_number
    render :xml => telephony.initiate_agent_conference({
      :wait_url => "", 
      :sid => current_call.call_sid })
  end

  def direct_dial_complete
    if params[:AnsweredBy] == "machine"
      params[:DialCallStatus] = "no-answer"
      current_call.disconnect_customer
    elsif params[:CallStatus] == "canceled"
      params[:DialCallStatus] = "no-answer"
    elsif params[:CallStatus] == "no-answer" || params[:CallStatus] == "busy" || params[:CallStatus] == "failed"
      params[:DialCallStatus] = "no-answer"
      initiate_voicemail
    else
      params[:DialCallStatus] = "completed"
    end
    current_call.update_status(params).save!
    empty_twiml
  end

  def initiate_custom
    render xml: telephony.custom_forwarding_response(caller_name,
      custom_forwarding_url, current_call.freshfone_number.voice_type)
  end

  def initiate_custom_transfer
    render xml: telephony.custom_forwarding_response(current_call.agent_name,
      transfer_forwarding_url, current_call.freshfone_number.voice_type)
  end

  def process_custom
    return initiate if custom_forward_accept?
    return handle_ignored_call if custom_forward_reject?
    render_invalid_input(custom_forwarding_url, caller_name)
  end

  def process_custom_transfer
    return handle_transfer_accept if custom_forward_accept?
    return empty_twiml if custom_forward_reject?
    render_invalid_input(transfer_forwarding_url, current_call.agent_name)
  end

  private
    def telephony
      current_number ||= current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end

    def agent_call_leg
      @agent_leg ||= Freshfone::Initiator::AgentCallLeg.new(params, current_account, current_number, call_actions, telephony)
    end

    def transfer_leg
      @transfer_leg ||= Freshfone::Initiator::Transfer.new(params, current_account, current_number)
    end

    def notifier
      current_number = current_call.freshfone_number
      @notifier ||= Freshfone::Notifier.new(params, current_account, current_user, current_number)
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account, current_number)
    end

    def initiate_voicemail
      freshfone_number = current_call.freshfone_number
      telephony.redirect_call(current_call.call_sid, redirect_caller_to_voicemail(freshfone_number.id)) if call_in_progress?
    end

    def validate_twilio_request
      @callback_params = params.except(*[:call, :agent_id, :transferred_from, :agent, :external_number, :external_transfer, :caller_id, :timeout])
      super
    end

    def update_transfer_leg_call_meta(child)
      call_actions.update_agent_leg_response(params[:agent_id], params[:CallStatus], child)
    end

    def set_dial_call_sid
      params.merge!({ :DialCallSid => params[:CallSid], 
                      :DialCallStatus => params[:CallStatus] })
    end

    def call_forwarded?
      true
    end

    def answered_by_machine?
      params[:AnsweredBy] == 'machine'
    end

    def voicemail_preconditions?
      params[:CallStatus] = 'no-answer' if answered_by_machine?
      update_agent_leg_call_response(params[:CallStatus])
      (current_call.ringing? &&
        (answered_by_machine? || ignored_call?) &&
         all_agents_missed?)
    end

    def set_external_transfer_params
      params[:external_transfer] = 'true' unless params[:external_number].blank?
    end

    def check_and_initiate_voicemail
      current_call.update_attributes(:agent => nil)
      check_for_queued_calls
      initiate_voicemail
      empty_twiml
    end

    def transfer_ignored
      transferred_call = current_call.children.last
      params[:CallStatus] = 'no-answer' if answered_by_machine?
      params[:CallStatus] = 'busy' if custom_ignored_transfer?
      update_transfer_leg_call_meta(transferred_call)
      params[:DialCallStatus] = params[:CallStatus]
      transferred_call.update_call(params)
      notifier.notify_source_agent_to_reconnect(transferred_call) if
        !transferred_call.canceled? && transferred_call.meta.all_agents_missed?
      render :xml => telephony.call_ignored(params) and return
    end

    def ignored_call?
      params[:CallStatus].present? &&
      %w(no-answer busy canceled failed).include?(params[:CallStatus])
    end

    def check_transfer_ignored?
      answered_by_machine? || ignored_call? || custom_ignored_transfer?
    end

    def call_in_progress?
      call_status = telephony.call_status(current_call.call_sid)
      return false if call_status.blank?
      Freshfone::Call::CALL_STATUS_HASH[call_status.to_sym] == Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
    end

    def set_tranfer_call
      @transferred_call = current_call.children.last
    end
    
    def update_agent_presence
      return unless (["failed", "completed"].include? params[:CallStatus])
      current_user = @transferred_call.agent
      current_user.freshfone_user.reset_presence.save! if current_user.present?
    end

    def set_child_call_status
      parent_call = current_account.freshfone_calls.find(params[:call])
      return if parent_call.blank? || !parent_call.inprogress? #checking for parent call is in progress, if so then child is canceled.
      parent_call.children.last.canceled!
      empty_twiml and return
    end

    def check_child_call_status
      empty_twiml and return if @transferred_call.missed_or_busy?
    end

    def create_or_update_call_meta(call)
      return update_call_meta_for_forward_calls(call) if call.meta.present?
      return if (/client/.match(params[:To]))
      call.create_meta( account_id: current_account.id,
        device_type: call.direct_dial_number.present? ?
          Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial] :
            Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:available_on_phone])
      set_agent_info(current_account.id, call.id,
        params[:To]) if call.meta.persisted?
    end

    def validate_trial
      return render :xml => telephony.reject('Trial Restriction')
    end

    def cancel_browser_agents
      return if current_call.user_id != (params[:agent_id].to_i)
      call_actions.cancel_browser_agents(current_call)
    end

    def custom_forwarding_url
      forward_initiate_url(params[:call], params[:agent_id])
    end

    def transfer_forwarding_url
      forward_transfer_url(params[:call], params[:agent_id])
    end

    def handle_ignored_call
      update_agent_leg_call_response(:busy)  # updating only agent-response here. call will move to voicemail if all-agents are missed
      empty_twiml                            #in round-robin or normal-flow based on the settings when status_callback event is triggered.
    end

    def update_agent_leg_call_response(response)
      call_actions.update_agent_leg_response(params[:agent_id] ||
        params[:agent], response, current_call)
    end

    def all_agents_missed?
      current_call.meta.all_agents_missed?
    end

    def custom_ignored_call?
      custom_forwarding_completed? && current_call.ringing?
    end

    def handle_incomplete_call
      update_agent_leg_call_response(:busy)
      return check_and_initiate_voicemail if all_agents_missed?
      empty_twiml
    end

    def custom_ignored_transfer?
      custom_forwarding_completed? && @transferred_call.ringing?
    end

    def custom_forwarding_completed?
      custom_forwarding_enabled? && params[:CallStatus] == 'completed'
    end

    def handle_transfer_accept
      set_tranfer_call
      return handle_already_accepted_call if already_inprogress?
      transfer_initiate
    end

    def already_inprogress?
      @transferred_call.inprogress? && connected_to_other_agent?
    end
    
    def connected_to_other_agent?
      @transferred_call.user_id != params[:agent_id].to_i
    end

    def handle_already_accepted_call
      Rails.logger.info "Handle Simultaneous Answer For Account Id :: #{current_account.id}, Call Id :: #{@transferred_call.id}, CallSid :: #{params[:CallSid]}, AgentId :: #{params[:agent_id]}"
      render xml: telephony.incoming_answered(@transferred_call.agent)
    end

    def new_notification_accepted_call?
      (params[:action] == 'initiate' ||
                             custom_forward_accept?)
    end
end
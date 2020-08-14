module Freshfone::FreshfoneUtil
  include Freshfone::NodeEvents
  include Freshfone::CallerLookup

  def default_client
    current_user.id
  end

  def split_client_id(caller_id)
    caller_id.match(/client:(\d+)/) ? $1 : nil if caller_id.present?
  end

  def sip_user_id(caller_id=params[:From])
    caller_id[/\d+/].to_i
  end

  def sip_call?
    params[:SipCallId].present? && params[:SipDomain].present? && params[:SipDomainSid].present?
  end

  def sip_number
    "+#{params[:To][/\d+/].to_i}"
  end

  def supervisor?
    params[:type] == 'supervisor'
  end

  def host
    current_account.url_protocol + "://" + current_account.full_domain
  end

  def empty_twiml
    twiml = Twilio::TwiML::Response.new
    render :xml => twiml.text
  end

  def comment_twiml(message)
    Twilio::TwiML::Response.new { |r|
      r.comment! "#{message}"
    }.text
  end
  
  def reject_twiml(comment = nil)
    Twilio::TwiML::Response.new { |r| 
      r.comment! comment if comment.present?
      r.Reject
    }.text
  end


  def notify_error(params)
    error_message = "Freshfone Error : Subaccount : #{current_account.freshfone_account.twilio_subaccount_id} \n ERROR CODE : #{params[:ErrorCode]} : #{params[:ErrorUrl]}"
    Rails.logger.error error_message
    NewRelic::Agent.notice_error(StandardError.new(error_message))
  end

  def freshfone_stats_debug(message, controller)
    Rails.logger.info "FRESHFONE STATS :: #{message}"
    Rails.logger.info "#{controller} :: #{current_account.full_domain} :: #{current_account.id}_#{current_user.id}"
  end

  def transfer_notifier(current_call,target_id,source_agent_id)
    handle_transfer_wait(target_id)
    return notifier.notify_group_transfer(current_call, target_id, source_agent_id) if group_transfer?
    return notifier.notify_external_transfer(current_call,target_id,source_agent_id) if external_transfer?
    notifier.notify_transfer(current_call, target_id, source_agent_id) 
  end

  def save_child_call_conf_meta(call,performer,type)
    return if call.blank?
    params[:call] = call.id
    transfer_by_agent = transfering_agent_id(call)
    call_actions = Freshfone::CallActions.new(params, current_account, call.freshfone_number)
    call_actions.save_conference_meta(type, performer, transfer_by_agent)
  end

  def update_call_meta(call)
    user_agent = request.env["HTTP_USER_AGENT"]
    unless call.meta.blank?
      Rails.logger.debug "Call Meta Already found for account: #{current_account.id} :: call : #{call.inspect} :: User Agent :: #{user_agent}"
      return
    end
    call_meta = Freshfone::CallMeta.new( :account_id => current_account.id, :call_id => call.id,
              :transfer_by_agent => transfering_agent_id(call))
    call_meta.device_type = is_native_mobile? ? mobile_device(user_agent) : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser]
    call_meta.save
    set_agent_info(current_account.id, call.id,
      user_agent) if call_meta.persisted?
  end

  def update_conf_meta
    return if current_call.blank?
    user_agent = request.env["HTTP_USER_AGENT"]
    current_call.meta = Freshfone::CallMeta.new( :account_id => current_account.id, :call_id => current_call.id) if current_call.meta.blank?
    call_meta = current_call.meta
    call_meta.transfer_by_agent = transfering_agent_id(current_call) if call_meta.transfer_by_agent.blank?
    call_meta.device_type = (is_native_mobile? ? mobile_device(user_agent) : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser]) if call_meta.device_type.blank?
    call_meta.save
    set_agent_info(current_account.id, current_call.id,
      user_agent) if call_meta.persisted?
  end

  def mobile_device(user_agent)
    user_agent[/#{AppConfig['app_name']}_Native_Android/].present? ?
      Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:android] : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:ios]
  end

  def transfering_agent_id(call)
    call.parent.user_id unless call.parent.blank?
  end

  #Method that sets the call_sid as dial callSid for the transfer leg. 
  def fetch_and_update_child_call(call_id,call_sid , agent_id = nil)
    parent_call  = current_account.freshfone_calls.find(call_id)
    transfer_leg = parent_call.children.last
    transfer_leg.direct_dial_number = format_external_number if external_transfer?
    options = update_call_options(call_sid, agent_id)
    transfer_leg.update_call(options)
    transfer_leg
  end 

  def handle_transfer_wait(target)
    return group_transfer_wait if group_transfer?
    return external_transfer_wait if external_transfer?
    saved = call_actions.register_call_transfer(target,current_call.outgoing?) 
    save_child_call_conf_meta(current_child_call,target,:agent)
    update_child_call_caller
  end

  def group_transfer_wait
    params[:group_id] = params[:group_id] || params[:target]
    call_actions.register_group_call_transfer(current_call.outgoing?) 
    save_child_call_conf_meta(current_child_call, params[:group_id] ,:group)
  end

  def external_transfer_wait
    params[:direct_dial_number] = params[:target]
    call_actions.register_external_transfer(current_call.outgoing?)
    save_child_call_conf_meta(current_child_call,params[:target],:number)
  end

  def outgoing_or_warm_transfer?(call)
    call.outgoing? && !call.is_root? && !call.meta.warm_transfer_meta?
  end

  def incoming_transfer?(call)
    call.incoming? && !call.is_root?
  end

  def transfered_leg?(call)
    incoming_transfer?(call) || outgoing_or_warm_transfer?(call)
  end

  def call_actions
    call_actions = Freshfone::CallActions.new(params, current_account, current_call.freshfone_number)
  end

  def update_call_options(call_sid, agent_id)
    options = { :DialCallSid => call_sid }
    options.merge!({ :agent => agent_id }) unless agent_id.blank?
    options
  end

  def current_child_call
    current_account.freshfone_calls.find(current_call.id).children.last if current_call.present?
  end

  def find_customer_by_number(phone_number)
    current_account.users.find_by_phone(phone_number) || current_account.users.find_by_mobile(phone_number)
  end

  def new_freshfone_account?(account)
    account.freshfone_account.blank?
  end

  def create_subaccount(account)
    account.create_freshfone_account
  end

  def group_transfer?
    params[:group_transfer] == "true"
  end

  def external_transfer?
    !params[:external_transfer].blank? && params[:external_transfer] == "true"
  end

  def busy_or_missed?(call_status)
    [ Freshfone::Call::CALL_STATUS_HASH[:busy], Freshfone::Call::CALL_STATUS_HASH[:missed] ].include?(call_status)
  end

  def format_external_number
    params[:external_number].start_with?("+") ? params[:external_number] : "+#{params[:external_number]}" 
  end

  def call_answered?
    current_call.agent.present? && (current_call.user_id == get_agent_id.to_i)
  end
  
  def get_agent_id
    return agent_id if agent_id.present?
    sip_user_id(params[:From]) if (current_call.sip?)
  end

  def agent_id
    params[:agent_id] || params[:agent]
  end

  def update_agent_last_call_at
    return unless (call_answered? && params[:direct_dial_number].blank?)
    freshfone_user = current_call.agent.freshfone_user
    freshfone_user.set_last_call_at(Time.now) 
  end

  def trigger_conference_transfer_wait(call = current_call)
    Resque.enqueue_at(ringing_time(call), Freshfone::ConferenceTransferWait,
      { :account_id => current_account.id, :call_id => call.id })
  end

  def ringing_time(call)
    ringing_duration = call.freshfone_number.ringing_duration
    ((ringing_duration/60).minutes + (ringing_duration%60).seconds + 1.minute).from_now
  end

  def remove_conf_transfer_job(call = current_call)
    Resque.remove_delayed(Freshfone::ConferenceTransferWait,
      { :account_id => current_account.id, :call_id => call.id })
  end

  def update_child_call_caller
    child_call = current_child_call
    return if (child_call.blank? || current_call.blank? || (child_call.present? && child_call.caller.present? ) )
    child_call.caller = current_call.caller
    child_call.save!
  end

  def update_call_meta_for_forward_calls(call = current_call)
    return if (/client/.match(params[:To]))
    device_type = call.direct_dial_number.present? ? Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial] : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:available_on_phone]
    call_meta = call.meta
    call_meta.device_type = device_type
    call_meta.save!
    set_agent_info(current_account.id, call.id, params[:To])
  end

  def register_outgoing_device
      agent_user_id = params[:type] == "sip" ? sip_user_id : outbound_call_agent_id
      set_outgoing_device([agent_user_id]) unless agent_user_id.blank?
  end

  def reject_outgoing_call
    agent_user_id = params[:type] == "sip" ? sip_user_id : outbound_call_agent_id
    unless agent_user_id.blank?
      agent = current_account.freshfone_users.find_by_user_id(agent_user_id).busy!
      Resque::enqueue(Freshfone::Jobs::BusyResolve, { :agent_id => agent_user_id })
    end
    telephony.reject
  end

  def outbound_call_agent_id
    split_client_id(params[:From]) || params[:agent]
  end

  def transfer_call?
    current_call.transferred_leg? ||
      params[:transfer_call].present? || params[:external_transfer].present?
  end

  def agent_connected?
    current_call.user_id.present? &&
      current_call.user_id.to_s == (params[:agent_id] || params[:agent])
  end

  def warm_transfer_enabled?
    current_account.features?(:freshfone_warm_transfer)
  end

  private
    def invalid_number_incoming_fix
      return if agent_leg? || agent_transfer_leg? || params[:From].blank? || sip_call? || supervisor?
      if !outgoing? && invalid_number?(params[:From]) && !strange_number?(params[:From])
        Rails.logger.info "Number :: #{params[:From]} is an Invalid Number, of CallSid :: #{params[:CallSid]} for Account :: #{current_account.id}"
        params[:From] = "+#{STRANGE_NUMBERS.invert['ANONYMOUS'].to_s}"
      end
    end

    def outgoing?
      current_account.features?(:freshfone_conference) ? params[:From].present? && params[:PhoneNumber].present? && params[:From].match(/(client:)/) : params[:To].blank? 
    end

    def warm_transfer_call_leg
      return @warm_transfer_call_leg ||= current_account.supervisor_controls.find(
        params[:warm_transfer_call_id]) if params[:warm_transfer_call_id].present?
      @warm_transfer_call_leg ||= current_account.supervisor_controls.find_by_sid(params[:CallSid])
    end

    def user_agent_key(warm_transfer_leg)
      FRESHFONE_USER_AGENT % { account_id: warm_transfer_leg.account_id,
                               user_id: warm_transfer_leg.supervisor_id,
                               warm_transfer_id: warm_transfer_leg.id }
    end

    def agent_leg?
      params[:type] == "agent_leg"
    end

    def agent_transfer_leg?
      params[:type] == "agent_transfer_leg"
    end

    def intended_agent?
      return true if current_call.user_id.blank?
      current_call.user_id.to_s == (params[:agent] || params[:agent_id])
    end

    def handle_simultaneous_answer
      Rails.logger.info "Handle Simultaneous Answer For Account Id :: #{current_account.id}, Call Id :: #{current_call.id}, CallSid :: #{params[:CallSid]}, AgentId :: #{params[:agent] || params[:agent_id]}"
      return incoming_answered unless intended_agent?
      current_call.noanswer? ? telephony.incoming_missed : incoming_answered
    end

    def incoming_answered
      telephony.incoming_answered(current_call.agent)
    end

    def remove_notification_failure_recovery(account_id, call_id)
      Resque.remove_delayed(Freshfone::NotificationFailureRecovery, {:account_id => account_id, :call_id => call_id})
    end
end

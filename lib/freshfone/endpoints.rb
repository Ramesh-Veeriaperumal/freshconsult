module Freshfone::Endpoints

  def outgoing_accept_url(call_id)
    "#{host}/freshfone/conference/outgoing_accepted?call=#{call_id}"
  end

  def outgoing_status_url(call_id,agent_id)
    "#{status_url}?call=#{call_id}&agent_id=#{agent_id}"
  end

  def forward_accept_url(call_id, agent_id)
    "#{host}/freshfone/forward/initiate?call=#{call_id}&agent_id=#{agent_id}"
  end

  def custom_accept_url(call_id, agent_id)
    "#{host}/freshfone/forward/initiate_custom?call=#{call_id}&agent_id=#{agent_id}"
  end

  def forward_status_url(call_id, agent_id)
    "#{host}/freshfone/forward/complete?call=#{call_id}&agent=#{agent_id}"
  end

  def client_accept_url(call_id, agent_id)
    "#{host}/freshfone/voice?caller_sid=#{call_id}&agent_id=#{agent_id}"
  end

  def simultaneous_call_queue_url
     "#{host}/freshfone/queue/redirect_to_queue"
  end

  def client_status_url(call_id, agent_id)
    "#{host}/freshfone/voice?caller_sid=#{call_id}&agent_id=#{agent_id}&leg_type=disconnect"
  end

  def mobile_transfer_accept_url(call_id, source_agent_id, target_agent_id)
    "#{host}/freshfone/forward/transfer_initiate?call=#{call_id}&agent_id=#{target_agent_id}&transferred_from=#{source_agent_id}"
  end

  def custom_mobile_transfer_url(call_id, source_agent_id, target_agent_id)
    "#{host}/freshfone/forward/initiate_custom_transfer?call=#{call_id}&agent_id=#{target_agent_id}&transferred_from=#{source_agent_id}"
  end

  def mobile_transfer_status_url(call_id, agent_id)
    "#{host}/freshfone/forward/transfer_complete?call=#{call_id}&agent_id=#{agent_id}"
  end

  def transfer_accept_url(call_id,source_agent_id,agent_id)
    "#{host}/freshfone/conference_transfer/transfer_success?call=#{call_id}"
  end

  def external_transfer_accept(call_id,source_agent_id,external_number)
    mobile_transfer_accept_url(call_id,source_agent_id,external_number)+"&external_number=#{external_number.strip}&external_transfer=true"
  end

  def external_transfer_complete(call_id,external_number)
    client_status_url(call_id,nil)+"&external_number=#{external_number}&external_transfer=true"
  end

  def direct_dial_accept(call_id)
    "#{host}/freshfone/forward/direct_dial_accept?call=#{call_id}"
  end

  def direct_dial_connect_url(call_id)
    "#{host}/freshfone/forward/direct_dial_connect?call=#{call_id}"
  end

  def direct_dial_complete(call_id)
    "#{host}/freshfone/forward/direct_dial_complete?call=#{call_id}"
  end

  def warm_transfer_url
    "#{host}/freshfone/conference_transfer/transfer_source_redirect"
  end

  def status_url
    "#{host}/freshfone/conference_call/status"
  end

  def wait_url
    "#{host}/freshfone/conference/wait?#{call_params}"
  end

  def direct_dial_wait_url
    "#{host}/freshfone/forward/direct_dial_wait?#{call_params}"
  end

  def transfer_wait_url
    "#{host}/freshfone/forward/transfer_wait"
  end

  def incoming_agent_wait_url
    "#{host}/freshfone/conference/incoming_agent_wait"
  end

  def connect_incoming_caller_url
    "#{host}/freshfone/conference/connect_incoming_caller"
  end
  
  def agent_wait_url(call_id)
    "#{host}/freshfone/conference/agent_wait?call=#{call_id}"
  end

  def hold_wait_url
    "#{host}/freshfone/hold/wait?call=#{params[:call]}#{transfer_params}"
  end

  def hold_quit_url
    "#{host}/freshfone/hold/quit?call=#{params[:call]}"
  end

  def transfer_params
    return if params[:transfer].blank?
    "&transfer=#{params[:transfer]}&source=#{params[:source]}&target=#{params[:target]}&group_transfer=#{params[:group_transfer]}&transfer_type=#{params[:transfer_type]}#{external_transfer_param}"
  end

  def external_transfer_param
    return if params[:external_transfer].blank?
    "&external_transfer=#{params[:external_transfer]}"
  end

  def unhold_url(call_id = nil)
    "#{host}/freshfone/hold/unhold?call=#{call_id}"
  end

  def transfer_on_unhold_url(call_id)
    "#{host}/freshfone/hold/transfer_unhold?child_sid=#{params[:child_sid]}&call=#{call_id}"
  end

  def transfer_fall_back_url(call_id)
    "#{host}/freshfone/hold/transfer_fallback_unhold?call=#{call_id}"
  end

  def quit_voicemail_url
    "#{host}/freshfone/voicemail/quit_voicemail"
  end

  def enqueue_url
    "#{host}/freshfone/queue/enqueue" 
  end

  def quit_queue_url
    "#{host}/freshfone/queue/hangup"
  end

  def force_termination_url
    "#{host}/freshfone/call/status?force_termination=true"
  end

  def direct_dial_url(number)
    "#{status_url}?direct_dial_number=#{CGI.escape(format_number(number))}"
  end

  def target_agent_wait_url
    "#{host}/freshfone/conference_transfer/transfer_agent_wait"
  end

  def browser_agent_wait_url(id)
    "#{host}/freshfone/conference_transfer/transfer_agent_wait?call=#{id}"
  end

  def initiate_hold_url(customer_sid, transfer_options)
    "#{host}/freshfone/hold/initiate?hold_queue=hold_#{customer_sid}#{transfer_options}"
  end

  def transfer_status_url(call_id, agent_id, warm_transfer_forward = false)
    "#{client_status_url(call_id, agent_id)}&transfer_call=true#{'&forward=true' if warm_transfer_forward}"
  end

  def agent_conference_accept_url(call_id, add_agent_call_id)
    "#{host}/freshfone/agent_conference/success?call=#{call_id}&add_agent_call_id=#{add_agent_call_id}"
  end

  def custom_agent_conference_url(call_id, add_agent_call_id)
    "#{host}/freshfone/agent_conference/initiate_custom_forward?call=#{call_id}&add_agent_call_id=#{add_agent_call_id}"
  end

  def agent_conference_status_url(call_id, add_agent_call_id)
    "#{host}/freshfone/agent_conference/status?call=#{call_id}&add_agent_call_id=#{add_agent_call_id}"
  end

  def round_robin_call_status_url(current_call, agent_id, fwd_call = false)
    "#{client_status_url(current_call.id, agent_id)}&round_robin_call=true#{'&forward_call=true' if fwd_call}"
  end

  def round_robin_agent_wait_url(current_call)
    "#{host}/freshfone/conference_call/in_call?round_robin_call=true&ParentCallSid=#{current_call.call_sid}"
  end

  def redirect_caller_to_voicemail(number_id)
    "#{host}/freshfone/voicemail/initiate?freshfone_number=#{number_id}"
  end

  def recording_call_back_url
    "#{host}/freshfone/conference_call/update_recording"
  end

  def record_message_url
    "#{host}/freshfone/device/record?agent=#{params[:agent]}&number_id=#{params[:number_id]}"
  end

  def forward_params
    return unless params[:forward]
    "&forward=#{params[:forward]}"
  end

  def caller_id_status_verification_url
    "#{host}/phone/caller_id/add"
  end

  def warm_transfer_accept_url(warm_transfer_call_id, call_id)
    "#{host}/freshfone/warm_transfer/success?warm_transfer_call_id=#{warm_transfer_call_id}&call=#{call_id}"
  end

  def custom_warm_transfer_url(warm_transfer_call_id, call_id)
    "#{host}/freshfone/warm_transfer/initiate_custom_forward?warm_transfer_call_id=#{warm_transfer_call_id}&call=#{call_id}"
  end

  def warm_transfer_unhold_url(call)
    "#{host}/freshfone/warm_transfer/unhold?call=#{call}"
  end

  def warm_transfer_wait_url
    "#{host}/freshfone/warm_transfer/wait?call=#{params[:call]}#{transfer_params}#{warm_transfer_wait_params}"
  end

  def warm_transfer_quit_url
    "#{host}/freshfone/warm_transfer/quit?call=#{params[:call]}"
  end

  def warm_transfer_wait_params
    "&warm_transfer_call_id=#{params[:warm_transfer_call_id]}" if params[:transfer_type] == 'warm_transfer'
  end

  def join_agent_url(call)
    "#{host}/freshfone/warm_transfer/join_agent?call=#{call}"
  end

  def redirect_customer_url(call)
    "#{host}/freshfone/warm_transfer/redirect_customer?call=#{call}"
  end

  def warm_transfer_agent_wait_url
    "#{host}/freshfone/warm_transfer/transfer_agent_wait"
  end

  def redirect_source_url(call_id)
    "#{host}/freshfone/warm_transfer/redirect_source_agent?warm_transfer_call_id=#{call_id}"
  end

  def forward_initiate_url(call_id, agent_id)
    "#{host}/freshfone/forward/process_custom?call=#{call_id}&agent_id=#{agent_id}"
  end

  def forward_transfer_url(call_id, agent_id)
    "#{host}/freshfone/forward/process_custom_transfer?call=#{call_id}&agent_id=#{agent_id}"
  end

  def forward_agent_conference_url(call_id, add_agent_call_id)
    "#{host}/freshfone/agent_conference/process_custom_forward?call=#{call_id}&add_agent_call_id=#{add_agent_call_id}"
  end

  def forward_warm_transfer_url(warm_transfer_call_id, call_id)
    "#{host}/freshfone/warm_transfer/process_custom_forward?warm_transfer_call_id=#{warm_transfer_call_id}&call=#{call_id}"
  end

  private 
    def call_params
      "caller_id=#{CGI.escape(params[:From])}&timeout=#{incoming_timeout}"
    end

    def incoming_timeout
      current_number.ringing_duration
    end

    def hunt_options
      "&hunt_type=#{@hunt[:type]}&hunt_id=#{CGI.escape(@hunt[:performer])}"
    end

    def hunt_params
      "?hunt_type=#{@hunt[:type]}&hunt_id=#{@hunt[:performer]}"
    end 

    def format_number(number)
      @number = TelephoneNumber.parse(number).e164_number
    end

end
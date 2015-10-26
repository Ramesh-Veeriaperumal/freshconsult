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

  def forward_status_url(call_id, agent_id)
    "#{host}/freshfone/forward/complete?call=#{call_id}&agent=#{agent_id}"
  end

  def client_accept_url(call_id, agent_id)
    "#{host}/freshfone/voice?caller_sid=#{call_id}&agent_id=#{agent_id}"
  end

  def client_status_url(call_id, agent_id)
    "#{host}/freshfone/voice?caller_sid=#{call_id}&agent_id=#{agent_id}&leg_type=disconnect"
  end

  def connect_agent_url
    "#{host}/freshfone/voice?caller_sid=#{params[:caller_sid] || params[:call]}&agent_id=#{params[:agent_id] || params[:agent]}&leg_type=connect"
  end

  def mobile_transfer_accept_url(call_id, source_agent_id, target_agent_id)
    "#{host}/freshfone/forward/transfer_initiate?call=#{call_id}&agent_id=#{target_agent_id}&transferred_from=#{source_agent_id}"
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

  def initiate_hold_url(customer_sid, transfer_options)
    "#{host}/freshfone/hold/initiate?hold_queue=hold_#{customer_sid}#{transfer_options}"
  end

  def transfer_status_url(call_id, agent_id)
    "#{client_status_url(call_id, agent_id)}&transfer_call=true"
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
      @number = GlobalPhone.parse(number).international_string
    end

end
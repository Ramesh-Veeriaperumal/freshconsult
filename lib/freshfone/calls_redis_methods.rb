module Freshfone::CallsRedisMethods
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  def log_transfer(user_id = params[:id], call_sid = transfer_sid)
    key = FRESHFONE_TRANSFER_LOG % { :account_id => current_account.id, :call_sid => call_sid }
    calls = get_key(key)
    transferred_calls = (calls) ? JSON.parse(calls) : []
    transfer_id = (user_id == "0" && params[:group_id].present?) ?  params[:group_id] : user_id
    transferred_calls << transfer_id
    set_key(key, transferred_calls.to_json)
  end

  def register_ivr_preview
    set_key preview_ivr_key, "", 1800
  end

  def ivr_preview?
    !get_key(preview_ivr_key).nil?
  end

  def remove_ivr_preview
    remove_key preview_ivr_key
  end

  def register_supervisor_leg(account_id, agent_id, sid, call_id)
    set_key supervisor_leg_key(account_id, agent_id, sid), call_id#, 1800
  end

  def get_call_id_from_redis(account_id,agent_id, sid)
    get_key supervisor_leg_key(account_id, agent_id, sid)
  end

  def remove_supervisor_leg(account_id, agent_id, sid)
    remove_key supervisor_leg_key(account_id, agent_id, sid)
  end

  def transfer_sid
    call_sid = params[:call_sid] || params[:CallSid]
    (params[:outgoing].to_bool) ? call_sid : 
          current_account.freshfone_subaccount.calls.get(call_sid).parent_call_sid
  end

  def update_transfer_log(user_id)
    call_sid = params[:outgoing] ? params[:ParentCallSid] : params[:CallSid]
    log_transfer(user_id, call_sid)
  end

  def set_outgoing_device(device_id)
    outgoing_key
    add_to_set(@key, device_id)
  end

  def remove_device_from_outgoing(device_id)
    outgoing_key
    remove_value_from_set(@key, device_id)
  end

  def outgoing_key
    @key ||= FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => current_account.id }
  end

  def preview_ivr_key
    @preview_ivr_key  ||= FRESHFONE_PREVIEW_IVR % { :account_id => current_account.id, :call_sid => params[:CallSid] }
  end

  def supervisor_leg_key(account_id, agent_id, sid)
    @supervisor_leg_key  ||= FRESHFONE_SUPERVISOR_LEG % { :account_id =>  account_id, :user_id => agent_id, :call_sid => sid }
  end

  def autorecharge_key(account_id)
    FRESHFONE_AUTORECHARGE_TIRGGER % {:account_id => account_id}
  end

  def autorecharge_inprogress?(account_id)
    return if get_key(autorecharge_key(account_id)).blank?
    Rails.logger.info "Auto-Recharge attempt with in 30 mins for account #{account_id}"
    true
  end

  #Conference actions
  def store_agents_in_redis(current_call, available_agents)
    key = FRESHFONE_AGENTS_BATCH % { :account_id => @current_account.id, :call_sid => current_call.call_sid }
    pinged_agents_ids = available_agents.map { |agent| agent[:ff_user_id]}.compact.to_json
    set_key(key, pinged_agents_ids, 600)
  end

   def clear_batch_key(call_sid)    
      key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => call_sid }    
      remove_key(key)    
  end

  def batch_key_exists?(call_sid)
    key = FRESHFONE_AGENTS_BATCH % { account_id: current_account.id, call_sid: call_sid }
    Rails.logger.info "Exists Check :: Batch Key Name :: #{key}"
    key_exists?(key)
  end

  def set_browser_sid(child, parent) #Use mset and multi expire
    #additional 120 seconds is considering the minute rtt time it takes to create each call
    set_key browser_key(child), parent, (incoming_timeout + 120)
  end

  def get_browser_sid
    get_key browser_key(params[:CallSid])
  end

  def browser_key(child_sid)
    @browser_key ||= FRESHFONE_CALL % { :account_id => current_account.id, :child_sid => child_sid }
  end

  def add_pinged_agents_call(call_id, agent_call_sid)
    key = pinged_agents_key(call_id)
    add_to_set(key, agent_call_sid)
    $redis_integrations.perform_redis_op("expire", key, 1800)
  end

  def get_pinged_agents_call(call_id)
    integ_set_members(pinged_agents_key(call_id))
  end

  def pinged_agents_key(call_id, account = current_account)
    @pinged_agents_key ||= FRESHFONE_PINGED_AGENTS % { :account_id => account.id, :call_id => call_id } 
  end

  def call_notable_key
    @call_notes_key ||= FRESHFONE_CALL_NOTABLE % {
      account_id: @current_account.id, call_id: @call_id }
  end

  def call_quality_metrics_key(dial_call_sid)
    @call_quality_metrics_key ||= FRESHFONE_CALL_QUALITY_METRICS % {
      account_id: @current_account.id, dial_call_sid: dial_call_sid }
  end

  def agent_response_key(account_id, call_id)
    FRESHFONE_PINGED_RESPONSE % { account_id: account_id, call_id: call_id }
  end

  def agent_info_key(account_id, call_id)
    FRESHFONE_AGENT_INFO % { account_id: account_id, call_id: call_id }
  end

  def voicemail_initiated_key(account_id, call_id)
    FRESHFONE_VOICEMAIL_CALL % { account_id: account_id, call_id: call_id }
  end

  def set_agent_response(account_id, call_id, agent_id, response)
    key = agent_response_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hset', key, agent_id.to_s, response)
  end

  def set_all_agents_response(account_id, call_id, agent_responses)
    key = agent_response_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hmset', key , agent_responses)
  end

  def set_voicemail_key(account_id, call_id)
    key = voicemail_initiated_key(account_id, call_id)
    set_key(key, '', 900)
  end

  def get_voicemail_key(account_id, call_id)
    key = voicemail_initiated_key(account_id, call_id)
    get_key(key)
  end

  def get_response_meta(account_id, call_id)
    key = agent_response_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hgetall', key)
  end

  def get_agent_response(account_id, call_id, user_id)
    key = agent_response_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hget', key, user_id)
  end

  def set_agent_info(account_id, call_id, agent_info)
    key = agent_info_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hset', key, 'agent_info', agent_info)
  end

  def get_agent_info(account_id, call_id)
    key = agent_info_key(account_id, call_id)
    $redis_integrations.perform_redis_op('hgetall', key)
  end

  def get_and_clear_redis_meta(call)
    $redis_integrations.multi do
      get_redis_meta(call.account_id, call.id)
      remove_value_from_set(pinged_agents_key(call.id,
        call.account), call.call_sid)
    end
  end

  def get_redis_meta(account_id, call_id)
    $redis_integrations.multi do
      get_response_meta(account_id, call_id)
      get_agent_info(account_id, call_id)
      remove_key(agent_response_key(account_id, call_id))
      remove_key(agent_info_key(account_id, call_id))
    end
  end
end
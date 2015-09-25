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

  def autorecharge_key(account_id)
    FRESHFONE_AUTORECHARGE_TIRGGER % {:account_id => account_id}
  end

  def auto_recharge_throttle_limit_reached?(account_id)
    is_exist = get_key(autorecharge_key(account_id))
    Rails.logger.info "Auto-Recharge attempt with in 30 mins for account #{account_id}" unless is_exist.blank?
    return is_exist.blank?
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
    $redis_integrations.expire(key, 1800)
  end

  def get_pinged_agents_call(call_id)
    integ_set_members(pinged_agents_key(call_id))
  end

  def pinged_agents_key(call_id)
    @pinged_agents_key ||= FRESHFONE_PINGED_AGENTS % { :account_id => current_account.id, :call_id => call_id } 
  end

end
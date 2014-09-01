module Freshfone::CallsRedisMethods
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  def log_transfer(user_id = params[:id], call_sid = transfer_sid)
    key = FRESHFONE_TRANSFER_LOG % { :account_id => current_account.id, :call_sid => call_sid }
    calls = get_key(key)
    transferred_calls = (calls) ? JSON.parse(calls) : []
    transferred_calls << user_id
    set_key(key, transferred_calls.to_json)
  end

  def transfer_sid
    (params[:outgoing].to_bool) ? params[:call_sid] : 
          current_account.freshfone_subaccount.calls.get(params[:call_sid]).parent_call_sid
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
end
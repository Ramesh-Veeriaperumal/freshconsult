module Freshfone::Call::CallCallbacks

  def self.included(base)
    base.send :before_filter, :set_dial_call_sid, 
      :only => [:in_call, :call_transfer_success, :direct_dial_success]
  end

  def in_call
    update_presence_and_publish_call(params, message) if params[:agent].present?
    in_call_meta_info if current_call.incoming?
    current_call.update_call(params)
    return empty_twiml
  end

  def direct_dial_success
    in_call_meta_info if current_call.incoming?
    call_and_presence_update
    return empty_twiml
  end

  def call_transfer_success
    update_agent_presence(params[:source_agent]) unless params[:call_back].to_bool
    current_call.user_id  ||= params[:agent] if params[:group_transfer] && params[:group_transfer].to_bool
    current_call.update_call(params)
    return empty_twiml
  end

  def external_transfer_success
    transfer_call_meta_info
    call_and_presence_update
    return empty_twiml
  end

  private
    def message
      message = {:agent => params[:agent]}
      message.merge!({:answered_on_mobile => true}) if params[:forward].present?
    end

    def set_dial_call_sid
      params.merge!({ :DialCallSid => params[:CallSid], 
                      :DialCallStatus => params[:CallStatus] })
    end

    def call_and_presence_update
      current_call.update_call(params)
      update_agent_presence_for_direct(params[:source_agent]) unless params[:source_agent].blank?
      publish_live_call(params)
    end

    def in_call_meta_info
      return if (/client/.match(params[:To]))
      device_type = params[:direct_dial_number].blank? ? Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:available_on_phone] :
        Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial]
      Freshfone::CallMeta.create( :account_id => current_account.id, :call_id => current_call.id,
                :meta_info => params[:To], 
                :transfer_by_agent => transfering_agent_id(current_call),
                :device_type => device_type) if current_call.meta.blank?
    end

    def transfer_call_meta_info
      Freshfone::CallMeta.create( :account_id => current_account.id, :call_id => current_call.id,
                :meta_info => params[:To], 
                :transfer_by_agent => transfering_agent_id(current_call),
                :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer]) if current_call.meta.blank?
    end

end
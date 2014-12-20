module Freshfone::Call::CallCallbacks

  def self.included(base)
    base.send :before_filter, :set_dial_call_sid, 
      :only => [:in_call, :call_transfer_success, :direct_dial_success]
  end

  def in_call
    update_presence_and_publish_call(params, message) if params[:agent].present?
    current_call.update_call(params)
    return empty_twiml
  end

  def direct_dial_success
    current_call.update_call(params)
    publish_live_call(params)
    return empty_twiml
  end

  def call_transfer_success
    update_agent_presence(params[:source_agent]) unless params[:call_back].to_bool
    current_call.user_id  ||= params[:agent] if params[:group_transfer] && params[:group_transfer].to_bool
    current_call.update_call(params)
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

end
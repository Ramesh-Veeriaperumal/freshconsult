module Freshfone::FreshfoneHelper
  include Freshfone::NodeEvents

  def default_client
    current_user.id
  end

  def split_client_id(caller_id)
    caller_id.match(/client:(\d+)/) ? $1 : nil
  end

  def host
    current_account.url_protocol + "://" + current_account.full_domain
  end

  def empty_twiml
    twiml = Twilio::TwiML::Response.new
    render :xml => twiml.text
  end
  
  def reject_twiml
    Twilio::TwiML::Response.new { |r| r.Reject }.text
  end


  def notify_error(params)
    error_message = "Freshfone Error : Subaccount : #{current_account.freshfone_account.twilio_subaccount_id} \n ERROR CODE : #{params[:ErrorCode]} : #{params[:ErrorUrl]}"
    Rails.logger.error error_message
    NewRelic::Agent.notice_error(StandardError.new(error_message))
  end

  def update_call_meta(call)
    user_agent = request.env["HTTP_USER_AGENT"]
    unless call.meta.blank?
      Rails.logger.debug "Call Meta Already found for account: #{current_account.id} :: call : #{call.inspect} :: User Agent :: #{user_agent}"
      return
    end
    call_meta = Freshfone::CallMeta.new( :account_id => current_account.id, :call_id => call.id,
              :meta_info => user_agent )
    call_meta.device_type = is_native_mobile? ? mobile_device(user_agent) : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser]
    call_meta.save
  end

  def mobile_device(user_agent)
    user_agent[/#{AppConfig['app_name']}_Native_Android/].present? ?
      Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:android] : Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:ios]
  end

  def find_customer_by_number(phone_number)
    current_account.users.find_by_phone(phone_number) || current_account.users.find_by_mobile(phone_number)
  end

end

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

end

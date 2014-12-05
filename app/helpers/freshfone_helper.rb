module FreshfoneHelper
	include Freshfone::NodeEvents

	def default_client
		current_user.id
	end

	def split_client_id(caller_id)
		caller_id.match(/client:(\d+)/) ? $1 : nil
	end

	def host
		current_account.main_url_protocol + "://" + current_account.full_domain
	end

	def validate_freshfone_request
    token = current_account.freshfone_account.token
    signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
    url = host + "/" + params[:controller] + "/" + params[:action]
    url += "?agent=#{params[:agent]}" if params[:action] == 'forward'
		url += "/#{params[:id]}" if params[:action] == 'ivr'
    validator = Twilio::Util::RequestValidator.new token
    result = validator.validate(url, params.except(*validation_exclude_methods), signature)
    head :ok unless result  ## Return empty response on failed validation.. Returning 400(Bad Request) causes Twilio to resend the request and fail again.
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

  #Used in filter_options
  def call_types
    all_calls = [[t('reports.freshfone.all_call_types'), "0"]]
    all_calls + Freshfone::Call::CALL_TYPE_HASH.map { |k,v| [t("reports.freshfone.options.#{k}"), v]}
  end

  def validation_exclude_methods ##Temp
  	[:action, :controller, :agent, :id]
  end

end

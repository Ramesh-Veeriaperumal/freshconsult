class FreshfoneBaseController < ApplicationController
	include TwilioMaster	
	
	skip_before_filter :check_privilege, :if => :public_method?
	before_filter { |c| c.requires_feature :freshfone }
	before_filter :validate_twilio_request, :if => :public_method?
	before_filter :reject_call, :if => :call_initiation_method?

  protected
    
    def validate_twilio_request
    	token = current_account.freshfone_account.token
	    signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
	    validator = Twilio::Util::RequestValidator.new token
	    @callback_url ||= request.url; @callback_params ||= params
	    result = validator.validate(@callback_url, @callback_params.except(:action, :controller), signature)
	    ## Return empty response on failed validation.. Returning 400(Bad Request) causes Twilio to resend the request and fail again.
	    head :ok unless result 
    end
		
		def reject_call
			if current_account.freshfone_credit.below_calling_threshold?
				Rails.logger.debug "current_account :: #{current_account}, account_sid :: #{params[:AccountSid]}, call_sid :: #{params[:CallSid]}"
				render :xml => Twilio::TwiML::Response.new { |r| r.Reject }.text
			end
		end

  private
  
  	def public_method?
  		PUBLIC_METHODS[controller_name.to_sym].include? action_name.to_sym
  	end

  	def call_initiation_method?
  		( CALL_INITIATION_METHODS[controller_name.to_sym] || [] ).include? action_name.to_sym
  	end
end
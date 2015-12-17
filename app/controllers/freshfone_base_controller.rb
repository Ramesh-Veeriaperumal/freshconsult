class FreshfoneBaseController < ApplicationController
	include TwilioMaster	
	include Freshfone::CallerLookup
	
	before_filter :check_privilege, :if => :restricted_method?
	before_filter :check_freshfone_feature
  before_filter :validate_twilio_request, :if => :public_method?
	before_filter :reject_call, :if => :call_initiation_method?

  protected
    
    def validate_twilio_request
      @twilio_auth_token ||= freshfone_account.token
      signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
      validator = Twilio::Util::RequestValidator.new @twilio_auth_token
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

    def freshfone_account
      current_account.freshfone_account 
    end

  private
    
    def check_freshfone_feature
      unless current_account.freshfone_enabled?
        Rails.logger.debug "Freshfone enabled validation failed ::: Account :: #{current_account.id}, account_sid :: #{params[:AccountSid]}, call_sid :: #{params[:CallSid]}"
        render :xml => Twilio::TwiML::Response.new { |r|
          r.comment! "freshfone enabled validation failed"
          r.Reject 
        }.text
      end 
    end
  
  	def public_method?
      PUBLIC_METHODS[controller_name.to_sym].include? action_name.to_sym
  	end

    def restricted_method?
      !public_method?
    end

  	def call_initiation_method?
  		( CALL_INITIATION_METHODS[controller_name.to_sym] || [] ).include? action_name.to_sym
  	end

    def invalid_number_incoming_fix
      return if params[:From].blank? || sip_call?
      if invalid_number?(params[:From]) && !strange_number?(params[:From])
        Rails.logger.info "Number :: #{params[:From]} is an Invalid Number, of CallSid :: #{params[:CallSid]} for Account :: #{current_account.id}"
        params[:From] = "+#{STRANGE_NUMBERS.invert['ANONYMOUS'].to_s}"
      end
    end

end
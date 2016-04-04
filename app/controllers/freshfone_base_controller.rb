class FreshfoneBaseController < ApplicationController
	include TwilioMaster
	include Freshfone::SubscriptionsUtil
	
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
			return if trial? && !trial_exhausted? # Not checking credit for trial state alone
			return reject_trial_call if trial_exhausted? || trial_expired?
			validate_credit
		end

    def freshfone_account
      current_account.freshfone_account 
    end

  private
    
    def check_freshfone_feature
      unless current_account.freshfone_enabled?
        Rails.logger.debug "Freshfone enabled validation failed ::: Account :: #{current_account.id}, account_sid :: #{params[:AccountSid]}, call_sid :: #{params[:CallSid]}"
        render :xml => telephony.reject('freshfone enabled validation failed')
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

    def reject_trial_call
      render xml: telephony.reject("Trial #{trial_exhausted? ? 'Exhausted' : 'Expired'}")
    end

    def validate_credit
      return unless current_account.freshfone_credit.below_calling_threshold?
      Rails.logger.debug "current_account :: #{current_account}, account_sid :: #{params[:AccountSid]}, call_sid :: #{params[:CallSid]}"
      render :xml => telephony.reject('Low Credit')
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new
    end
end
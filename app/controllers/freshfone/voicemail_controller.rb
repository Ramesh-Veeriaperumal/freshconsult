class Freshfone::VoicemailController <  FreshfoneBaseController
  
  include Freshfone::FreshfoneHelper
  include Freshfone::CallHistory
  include Freshfone::TicketActions
  
  before_filter :add_additional_params
  
  def quit_voicemail
    current_call.update_call(params)
    empty_twiml
  ensure
    if params[:cost_added].blank?
      Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, { 
                          :account_id => current_account.id,
                          :call => current_call.id,
                          :call_sid => params[:CallSid]}) 
      Rails.logger.debug "Added FreshfoneJob for call sid(quit_voicemail)::::: #{params[:CallSid]}}"
    end
  end

  private
    def add_additional_params
      params.merge!({:DialCallStatus => 'no-answer', :voicemail => true})
    end

    def validate_twilio_request
      @callback_params = params.except(*[:cost_added])
      super
    end
end
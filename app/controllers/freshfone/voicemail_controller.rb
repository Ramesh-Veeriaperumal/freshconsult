class Freshfone::VoicemailController <  FreshfoneBaseController
  
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::TicketActions
  
  before_filter :add_additional_params

  def initiate #Used only in conference currently
    render :xml => telephony.return_non_availability(false)
  end
  
  def quit_voicemail
    current_call.set_call_duration(params)
    current_call.update_call(params)
    empty_twiml
  ensure
    if params[:cost_added].blank? && !current_account.features?(:freshfone_conference)
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

    def current_number
      current_account.freshfone_numbers.find params[:freshfone_number]
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:freshfone_number, :cost_added])
      super
    end
end
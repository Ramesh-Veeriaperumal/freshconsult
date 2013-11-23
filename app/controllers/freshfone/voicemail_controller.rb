class Freshfone::VoicemailController <  FreshfoneBaseController
  
  include FreshfoneHelper
  include Freshfone::CallHistory
  include Freshfone::TicketActions
  
  before_filter :add_additional_params
  
  def quit_voicemail
    build_ticket
    update_call

    empty_twiml
  ensure
    Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, { 
                          :account_id => current_account.id,
                          :call => current_call.id,
                          :call_sid => params[:CallSid]})
    Rails.logger.debug "Added FreshfoneJob for call sid(quit_voicemail)::::: #{params[:CallSid]}}"
  end

  private
    def add_additional_params
      params.merge!({:DialCallStatus => 'no-answer', :voicemail => true})
    end
end
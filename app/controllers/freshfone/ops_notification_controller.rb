class Freshfone::OpsNotificationController < FreshfoneBaseController
  include Freshfone::FreshfoneHelper
    
  skip_before_filter :check_freshfone_feature

  def voice_notification
    speak_message
  end

  def status
    empty_twiml
  end

  private
    def speak_message
      twiml = Twilio::TwiML::Response.new do |r|
        r.Say params[:message]
      end
      render :xml => twiml.text
    end

    def validate_twilio_request
      @callback_params = params.except(*[:id, :message])
      @twilio_auth_token = FreshfoneConfig['twilio']['auth_token']
      super
    end

end
class Freshfone::VoicemailController <  FreshfoneBaseController
  
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::TicketActions
  include Freshfone::CallsRedisMethods
  
  before_filter :add_additional_params
  before_filter :validate_transcription, only: :transcribe, unless: :transcription_enabled?
  before_filter :validate_call, only: :transcribe
  after_filter :set_voicemail_key_in_redis, only: :initiate

  def initiate #Used only in conference currently
    remove_notification_failure_recovery(current_account.id, current_call.id) if current_call.ringing?
    current_call.update_missed_abandon_status unless (current_call.present? && current_number.voicemail_active)
    current_call.voicemail_initiated!
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

  def transcribe
    jid = Freshfone::TranscriptAttachmentWorker.perform_in(40.seconds,
                                                           worker_params)
    Rails.logger.info "Transcript Attachment Worker:: Account ID:#{current_account.id}, Job-id:#{jid}, Worker Params:#{worker_params.inspect}"
    empty_twiml
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

    def transcription_enabled?
      current_account.has_feature?(:freshfone_vm_transcription)
    end

    def validate_transcription
      Rails.logger.info "Voicemail Transcription not Enabled for Account::#{current_account.id}"
      empty_twiml
    end

    def validate_call
      call = current_account.freshfone_calls.where(
        recording_url: recording_url).first
      return empty_twiml if call.blank?   #handling recording cases from numbers-settings page
      set_current_call(call)
    end

    def payload_url
      JSON.parse(params['AddOns'], symbolize_names: true
        )[:results][:ibm_watson_speechtotext][:payload].first[:url]
    end

    def recording_url
      payload_url.split('/AddOnResults').first
    end

    def worker_params
      {
        account_id: current_account.id,
        payload_url: payload_url,
        call: current_call.id
      }
    end

    def set_voicemail_key_in_redis
      set_voicemail_key(current_account.id, current_call.id)
    end
end
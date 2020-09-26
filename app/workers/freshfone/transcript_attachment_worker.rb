module Freshfone
  class TranscriptAttachmentWorker < BaseWorker
    include Freshfone::TicketActions

    sidekiq_options queue: :freshfone_trial_worker, retry: 0,
                    failures: :exhausted

    attr_accessor :params, :current_account

    def perform(params)
      Rails.logger.info 'Transcript Attachment Worker'
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "Transcript Params::#{params.inspect}"

      begin
        params.symbolize_keys!
        return if params[:account_id].blank?
        ::Account.reset_current_account

        Sharding.select_shard_of(params[:account_id]) do
          account = ::Account.find params[:account_id]
          account.make_current

          self.current_account = account
          self.params = params
          current_call = current_account.freshfone_calls.find(params[:call])
          return if current_call.blank? || current_call.ticket.blank?
          note_params = {
            ticket: current_call.ticket.id,
            call_log: transcribed_text,
            call: current_call.id,
            call_history: false,
            caller_name: current_call.customer_name,
            transcript_note: true,
            agent: current_account.technicians.find_by_email(current_account.admin_email)
          }
          Rails.logger.info "Creating Note with Params::#{note_params.inspect}"
          transcribed_note(note_params)
        end
      rescue => e
        Rails.logger.error "Error in Transcript Attachment Worker for Account:#{params[:account_id]} Call:#{params[:call]}. \n#{e.message}"
        NewRelic::Agent.notice_error(e, {description: "Error in TranscriptAttachment Worker for Account:#{params[:account_id]} Call:#{params[:call]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
      ensure
        ::Account.reset_current_account
      end
    end

    # fetch_transcribed_result['results'].first['results'] gives an array of transcripted-results and it will be empty if the recording is empty.
    # each array-element will have 'keywords_result' and 'alternatives'. 'keywords_result' contains the keywords identified in the sentence.
    # 'alternatives' hash will have 'timestamps', 'transcript' and 'confidence'. 'timestamps' contains the time alignments for each word from the
    # transcript as a list of lists. Each inner list consists of three elements: the word followed its start and end time in hundredths of seconds.
    # For example, [["hello",0.0,1.2],["world",1.2,2.5]]. 'transcript' contains the transcripted text.
    # 'confidence' contains a confidence score for the transcript in the range of 0 to 1.
    def transcribed_text
      transcribed_data = ''
      fetch_transcribed_result['results'].first['results'].each do |result|
        transcribed_data << ' ' + result['alternatives'].first['transcript']
      end
      transcribed_data
    end

    def fetch_transcribed_result
      ff_account = current_account.freshfone_account
      text_url = HTTParty.get(params[:payload_url], { basic_auth:
        { username: ff_account.twilio_subaccount_id,
          password: ff_account.twilio_subaccount_token },
        follow_redirects: false,
        'Accept' => 'application/json',
        timeout: 30 })
      HTTParty.get(text_url['TwilioResponse']['Data']['RedirectTo'])
    end
  end
end
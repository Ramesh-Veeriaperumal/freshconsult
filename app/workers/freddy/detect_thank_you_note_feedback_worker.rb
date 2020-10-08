module Freddy
  class DetectThankYouNoteFeedbackWorker < BaseWorker
    sidekiq_options queue: :thank_you_note, retry: 5

    SUCCESS = 200
    PRODUCT = 'freshdesk'.freeze
    ACTION = 'ticket_reopen_feedback'.freeze

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      ticket_id = args[:ticket_id]
      @ticket = account.tickets.find_by_id(ticket_id)
      @thank_you_notes = @ticket.schema_less_ticket.try(:thank_you_notes)
      url = FreddySkillsConfig[:detect_thank_you_note][:url] + ACTION
      http_response = {}
      time_taken = Benchmark.realtime { http_response = HTTParty.post(url, options) }
      Rails.logger.info "Time Taken for thank_you_ml_feedback - #{account.id} T - #{ticket_id} time - #{time_taken}"
      parsed_response = http_response.parsed_response
      Rails.logger.info "parsed_response = #{parsed_response.inspect}"
    rescue StandardError => e
      Rails.logger.error "Error in DetectThankYouNoteWorker::Exception:: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in DetectThankYouNoteWorker::Exception:: #{e.message}")
      raise e
    end

    private

      def options
        headers = { 'Content-Type' => 'application/json' }
        options = {
         headers: headers,
         body: body.to_json,
         timeout: FreddySkillsConfig[:detect_thank_you_note][:feedback_timeout]
        }
      end

      def body
        param_options = { ticket_status: @ticket.status_name }
        recent_note = @thank_you_notes.last
        { confidence: recent_note[:response][:confidence],
          feedback: 0,
          product: PRODUCT,
          account_id: Account.current.id,
          reopen: recent_note[:response][:reopen],
          text: @ticket.notes.find_by_id(recent_note[:note_id]).try(:body),
          options: param_options }
      end
  end
end

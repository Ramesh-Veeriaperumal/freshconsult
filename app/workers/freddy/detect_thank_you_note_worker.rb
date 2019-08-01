module Freddy
  class DetectThankYouNoteWorker < BaseWorker
    sidekiq_options queue: :thank_you_note, retry: 5, backtrace: true

    SUCCESS = 200
    ACTION = 'ticket_reopen'.freeze

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      ticket_id = args[:ticket_id]
      note_id = args[:note_id]
      ticket = account.tickets.find_by_id(ticket_id)
      note = ticket.notes.find_by_id(note_id)
      options = {}
      options[:headers] = { 'Content-Type' => 'application/json' }
      options[:body] = { text: note.try(:body) }.to_json
      options[:timeout] = FreddySkillsConfig[:detect_thank_you_note][:timeout]
      url = FreddySkillsConfig[:detect_thank_you_note][:url]
      url = url.ends_with?('ticket_reopen') ? url : url + ACTION
      http_response = {}
      time_taken = Benchmark.realtime { http_response = HTTParty.post(url, options) }
      Rails.logger.info "Time Taken for thank_you_ml - #{account.id} T - #{ticket_id} time - #{time_taken}"
      parsed_response = JSON.parse http_response.parsed_response
      if (parsed_response.is_a? Hash) && (http_response.code == SUCCESS)
        note.schema_less_note.thank_you_note = parsed_response.symbolize_keys
        note.schema_less_note.save!
      end
    rescue StandardError => e
      Rails.logger.error "Error in DetectThankYouNoteWorker::Exception:: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in DetectThankYouNoteWorker::Exception:: #{e.message}")
    end
  end
end

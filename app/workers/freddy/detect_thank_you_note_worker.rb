module Freddy
  class DetectThankYouNoteWorker < BaseWorker
    sidekiq_options queue: :thank_you_note, retry: 0, backtrace: true

    SUCCESS = 200
    PRODUCT = 'freshdesk'.freeze
    ACTION = 'ticket_reopen'.freeze

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      ticket_id = args[:ticket_id]
      note_id = args[:note_id]
      @ticket = account.tickets.find_by_id(ticket_id)
      @note = @ticket.notes.find_by_id(note_id)
      url = FreddySkillsConfig[:detect_thank_you_note][:url] + ACTION
      http_response = {}
      time_taken = Benchmark.realtime { http_response = HTTParty.post(url, options) }
      Rails.logger.info "Time Taken for thank_you_ml - A - #{account.id} T - #{ticket_id} time - #{time_taken}"
      Rails.logger.debug http_response.inspect.to_s
      parsed_response = http_response.parsed_response
      if (parsed_response.is_a? Hash) && (http_response.code == SUCCESS)
        @note.schema_less_note.thank_you_note = parsed_response.symbolize_keys
        @note.schema_less_note.save!
        thank_you_note = { note_id: @note.id, response: parsed_response.symbolize_keys }
        (@ticket.schema_less_ticket.thank_you_notes ||= []).push(thank_you_note)
        @ticket.schema_less_ticket.save!
      end
    rescue StandardError => e
      Rails.logger.error "Error in DetectThankYouNoteWorker::Exception::  A - #{account.id} T - #{ticket_id} #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in DetectThankYouNoteWorker::Exception:: #{e.message}")
    ensure
      trigger_observer(args)
    end

    private

      def options
        headers = { 'Content-Type' => 'application/json' }
        {
          headers: headers,
          body: body.to_json,
          timeout: FreddySkillsConfig[:detect_thank_you_note][:timeout]
        }
      end

      def body
        param_options = { ticket_status: @ticket.status_name }
        {
          text: @note.body,
          product: PRODUCT,
          account_id: Account.current.id,
          request_id: jid,
          options: param_options
        }
      end

      def trigger_observer(args)
        job_id = ::Tickets::ObserverWorker.perform_async(args)
        args[:job_id] = job_id
        log_observer_info(args)
      end

      def log_observer_info(args)
        Va::Logger::Automation.set_thread_variables(Account.current.id, args[:ticket_id], args[:doer_id], nil)
        Va::Logger::Automation.log("Triggering Observer from Detect Thank You Note Worker, job_id=#{args[:job_id]}, info=#{args.inspect}", true)
        Va::Logger::Automation.unset_thread_variables
      end
  end
end

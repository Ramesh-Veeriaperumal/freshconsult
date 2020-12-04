module Tickets
  class ConsultationReminderWorker < BaseWorker
    sidekiq_options :queue => :ticket_observer, :retry => 0, :failures => :exhausted

    def perform(args)
      @args = args.symbolize_keys!

      @consultation_type = 'Consultation'
      @status_ids = '3, 4, 5'
      @appoint_time_field = 'cf_fsm_appointment_start_time_' + @args[:account_id].to_s
      @time_to_notify = 900
      Sharding.run_on_slave do
        account = Account.find(args[:account_id]).make_current

        account.tickets.preload(:schema_less_ticket).where('ticket_type = ? AND status NOT IN (?)', @consultation_type, @status_ids).find_each do |ticket|
          next unless ticket.safe_send(@appoint_time_field).present?
          next if (ticket.safe_send(@appoint_time_field) - Time.zone.now.utc) > @time_to_notify
          next if ticket.schema_less_ticket.reports_hash.key?('reminder_sent')

          user = Account.current.users.find(ticket.requester_id)
          appointment = ticket.safe_send(@appoint_time_field).localtime
          meeting_url = ticket.schema_less_ticket.reports_hash['meeting_url']
          Sharding.run_on_master do
            ticket.schema_less_ticket.reports_hash.merge!('reminder_sent' => true)
            ticket.save!
          end
          Admin::ConsultationNotificationMailer.send_reminder_notification_email(user, appointment, meeting_url)
        end
      end
    ensure
      self.class.perform_in(120, @args) if Account.current.fresh_consult_enabled?
    end
  end
end

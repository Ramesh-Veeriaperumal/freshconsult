module Social::FB::Util
  include Helpdesk::IrisNotifications

  def notify_iris(note_id)
    note = Account.current.notes.find(note_id)
    ticket = note.notable
    iris_payload = generate_payload(ticket, note)
    Rails.logger.info "Pusing facebook reply failure notification for #{ticket.display_id}"
    push_data_to_service(IrisNotificationsConfig['api']['collector_path'], iris_payload)
  end

  def generate_payload(ticket, note)
    {
      payload: {
        ticket_display_id: ticket.display_id,
        ticket_subject: ticket.subject,
        note_id: note.id,
        user_id: note.user.id
      },
      payload_type: Social::FB::Constants::IRIS_NOTIFICATION_TYPE,
      account_id: Account.current.id.to_s
    }
  end
end

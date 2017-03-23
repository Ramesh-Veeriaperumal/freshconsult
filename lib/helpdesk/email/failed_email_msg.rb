class Helpdesk::Email::FailedEmailMsg
  def initialize(args)
    @note_id          = args[:note_id]
    @dynamodb_key     = args[:published_time]
    @failed_email     = args[:email]
    @failure_category = args[:failure_category]
  end

  def save!
    puts "FailedEmailMsg - Inside save! note_id: #{@note_id}, failed email: #{@failed_email}, dynamo: #{@dynamodb_key}"
    note        = Account.current.notes.where(id:@note_id).first
    @note_owner = note.user
    @recipient  = @note_owner.email
    @ticket     = note.notable
    note.dynamodb_range_key = @dynamodb_key
    if note.failure_count.present?
      note.failure_count += 1
    else
      note.failure_count  = 1
    end
    note.schema_less_note.save!
    puts "FailedEmailMsg - saved! note_id: #{@note_id}, failed email: #{@failed_email}, dynamo: #{@dynamodb_key}"
  end

  def notify
    puts "FailedEmailMsg - Inside notify. note_id: #{@note_id}, failed email: #{@failed_email}, dynamo: #{@dynamodb_key}"
    failed_content = @ticket.description
    ticket_url = "#{Account.current.url_protocol}://#{Account.current.full_domain}/helpdesk/tickets/#{@ticket.display_id}"
    type    = Helpdesk::Email::Constants::FAILURE_CATEGORY[@failure_category]
    error   = I18n.t("email_failure.#{type}.summary_error_text")
    subject = I18n.t('email_failure.agent_notification.subject',failed_email: @failed_email)
    content = I18n.t('email_failure.agent_notification.content',agent_name: @note_owner.name,ticket_id: @ticket.display_id,failed_email: @failed_email,error_message: error,failed_content: failed_content,ticket_url: ticket_url)
    Helpdesk::TicketNotifier.send_later(:internal_email, @ticket, @recipient, content, subject)
    puts "FailedEmailMsg - notified. note_id: #{@note_id}, failed email: #{@failed_email}, dynamo: #{@dynamodb_key}"
  end
end

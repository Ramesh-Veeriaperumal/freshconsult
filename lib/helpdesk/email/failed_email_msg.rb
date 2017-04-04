class Helpdesk::Email::FailedEmailMsg
  def initialize(args)
    @note_id          = args[:note_id]
    @dynamodb_key     = args[:published_time]
    @failed_email     = args[:email]
    @failure_category = args[:failure_category]
  end

  def save!
    @note         = Account.current.notes.where(id:@note_id).first
    @note_owner   = @note.user
    @recipient    = @note_owner.email
    @ticket       = @note.notable
    @note.dynamodb_range_key = @dynamodb_key
    if @note.failure_count.present?
      @note.failure_count += 1
    else
      @note.failure_count  = 1
    end
    @note.schema_less_note.save!
    Rails.logger.info "FailedEmailPoller: Saved! account_id: #{@note.account_id}, ticket_id: #{@ticket.id}, note_id: #{@note_id}, failed_email: #{@failed_email}, dynamo: #{@dynamodb_key}"
  end

  def notify
    template    = @ticket.account.email_notifications.find_by_notification_type(EmailNotification::EMAIL_DELIVERY_FAILURE_NOTIFICATION).get_agent_template(@note_owner)
    type        = Helpdesk::Email::Constants::FAILURE_CATEGORY[@failure_category]
    error       = I18n.t("email_failure.#{type}.summary_error_text")
    subject     = Liquid::Template.parse(template.first).render('ticket' => @ticket, 'note' => @note, 'failed_email' => @failed_email, 'error_message' => error).html_safe
    content     = Liquid::Template.parse(template.last).render('ticket' => @ticket, 'note' => @note, 'failed_email' => @failed_email, 'error_message' => error).html_safe
    Helpdesk::TicketNotifier.send_later(:internal_email, @ticket, @recipient, content, subject)
    Rails.logger.info "FailedEmailPoller: Notified action performer! account_id: #{@ticket.account_id}, ticket_id: #{@ticket.id}, note_id: #{@note_id}, failed_email: #{@failed_email}, dynamo: #{@dynamodb_key}"
  end
end

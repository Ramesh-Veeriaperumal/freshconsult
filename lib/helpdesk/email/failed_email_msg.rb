class Helpdesk::Email::FailedEmailMsg

  REQUESTER_EMAIL_FAILED  = {:mail_del_failed_requester => :failed}
  OTHER_EMAIL_FAILED      = {:mail_del_failed_others    => :failed}

  def initialize(args)
    @note_id          = args[:note_id]
    @dynamodb_key     = args[:published_time]
    @failed_email     = args[:email]
    @failure_category = args[:failure_category]
    @ticket           = args[:ticket]
    @object           = args[:object]
  end

  def save! is_note
    object_owner = is_note ? @object.user : outbound_initiator_or_agent(@object)
    if object_owner
      @recipient  = object_owner.email
      @agent_name = object_owner.name
    end
    @failed_content = is_note ? @object.body : @object.ticket_body.description
    @object.dynamodb_range_key = @dynamodb_key
    @object.failure_count = @object.failure_count.present? ? @object.failure_count+1 : 1
    @object.save!
    Rails.logger.info "FailedEmailPoller: Saved! account_id: #{@object.account_id}, ticket_id: #{@ticket.id}, note_id: #{@note_id}, failed_email: #{@failed_email}, dynamo: #{@dynamodb_key}"
  end

  def notify
    return unless @recipient
    I18n.with_locale(Helpdesk::TicketNotifier.mailer_language(@recipient)) do
      ticket_url = "#{Account.current.url_protocol}://#{Account.current.full_domain}/helpdesk/tickets/#{@ticket.display_id}"
      type    = Helpdesk::Email::Constants::FAILURE_CATEGORY[@failure_category]
      error   = I18n.t("email_failure.#{type}.summary_error_text")
      subject = I18n.t('email_failure.agent_notification.subject', failed_email: @failed_email)
      content = I18n.t('email_failure.agent_notification.content', agent_name: @agent_name, ticket_id: @ticket.display_id, failed_email: @failed_email, error_message: error, failed_content: @failed_content, ticket_url: ticket_url)
      Helpdesk::TicketNotifier.send_later(:internal_email, @ticket, @recipient, content, subject)
      Rails.logger.info "FailedEmailPoller: Notified action performer! account_id: #{@ticket.account_id}, ticket_id: #{@ticket.id}, note_id: #{@note_id}, failed_email: #{@failed_email}, dynamo: #{@dynamodb_key}"
    end
  end

  def trigger_observer_system_events
    event = @ticket.requester.emails.include?(@failed_email) ? REQUESTER_EMAIL_FAILED : OTHER_EMAIL_FAILED
    @object.trigger_observer(event,false,true)
  end

  private

  def outbound_initiator_or_agent ticket
    outbound_initiator = ticket.outbound_initiator
    outbound_initiator.agent? ? outbound_initiator : ticket.agent
  end
end

module NoteTestIntegrationsHelper
  include NoteTestHelper

  CUSTOMER_REPLIED_UNIQ_STRING = "handler LIKE '%- 6%'".freeze
  COMMENT_ADDED_UNIQ_STRING = "handler LIKE '%- 21%'".freeze
  CUSTOMER_RESPONDED_RULE = 'Automatically reopen tickets when the customer responds'.freeze
  CUSTOMER = true
  AGENT = false
  PRIVATE = 1
  PUBLIC = 0

  def enable_customer_responded_rule
    rule = @account.all_observer_rules.where(name: CUSTOMER_RESPONDED_RULE).first
    @account.reputation = 1
    @account.save
    rule.active = 1
    rule.save!
  end

  def disable_customer_responded_rule
    rule = @account.all_observer_rules.where(name: CUSTOMER_RESPONDED_RULE).first
    @account.reputation = 0
    @account.save
    rule.active = 0
    rule.save!
  end

  def new_resolved_ticket(source,category)
    ticket = create_ticket(:responder_id => 1, :source => source, :category => category)
    #user = add_new_user(@account)
    ticket.status = Helpdesk::Ticketfields::TicketStatus::RESOLVED
    ticket.save_ticket
    return ticket
  end

  def create_ticket_add_note(ticket_source, note_source,category, notification, note_type,contact)
    ticket = new_resolved_ticket(ticket_source,category)
    user = contact ? add_new_user(@account) : add_test_agent
    enable_customer_responded_rule
    notification_count = Delayed::Job.where(notification).all.count
    create_note(:private => note_type, :user_id => user.id, :source =>note_source)
    ticket.reload
    [notification_count ,ticket]
  end
end
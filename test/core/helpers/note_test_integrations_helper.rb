require_relative 'note_test_helper'

module NoteTestIntegrationsHelper
  include NoteTestHelper

  CUSTOMER_REPLIED_UNIQ_STRING = "handler LIKE '%- 6%'".freeze
  COMMENT_ADDED_UNIQ_STRING = "handler LIKE '%- 21%'".freeze
  AGENT_NOTE_ADDED_UNIQ_STRING = "handler LIKE '%notify_comment%'".freeze
  AGENT_REPLIED_STRING = "handler LIKE '%deliver_reply%'".freeze
  CUSTOMER_RESPONDED_RULE = 'Automatically reopen tickets when the customer responds'.freeze
  CUSTOMER = true
  AGENT = false
  PRIVATE = 1
  PUBLIC = 0
  def create_note_with_to_email(params = {})
    test_note = FactoryGirl.build(:helpdesk_note,
                                  :source => params[:source] || Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
                                  :notable_id => params[:ticket_id] || Helpdesk::Ticket.last.id,
                                  :created_at => params[:created_at],
                                  :user_id => params[:user_id] || @agent.id,
                                  :account_id => @account.id,
                                  :notable_type => 'Helpdesk::Ticket')
    test_note.incoming = params[:incoming] if params[:incoming]
    test_note.private = params[:private] if params[:private]
    test_note.category = params[:category] if params[:category]
    body = params[:body] || Faker::Lorem.paragraph
    test_note.build_note_body(:body => body, :body_html => params[:body_html] || body)
    if params[:attachments]
      params[:attachments].each do |attach|
        test_note.attachments.build(:content => attach[:resource],
                                    :description => attach[:description],
                                    :account_id => test_note.account_id)
      end
    end
    test_note.to_emails =["sample@freshdesk.com"]
    test_note.incoming = false
    test_note.save_note
    test_note
  end

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

  def create_ticket_add_agent_note(ticket_source, note_source,category, notification, note_type,contact,agent_as_requestor = false)
    ticket = new_resolved_ticket(ticket_source,category)
    user = contact ? add_new_user(@account) : add_test_agent
    if agent_as_requestor
      ticket.requester_id = user.id
      ticket.responder_id = user.id
      ticket.save
      ticket.reload
    end
    enable_customer_responded_rule
    notification_count = Delayed::Job.where(notification).all.count
    note = create_note_with_to_email(:private => note_type, :user_id => user.id, :source =>note_source,:incoming => false)
    ticket.reload
    [notification_count ,ticket]
  end
end
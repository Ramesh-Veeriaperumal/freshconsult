require_relative '../unit_test_helper'
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
class DeleteSpamTrashTicketTest < ActionView::TestCase
  include CreateTicketHelper

  def teardown
    Account.unstub(:current)
    super
  end

  def test_delete_spam_trash_ticket_with_spam_day_setting
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    Account.current.launch(:delete_trash_daily)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @ticket.deleted = true
    @ticket.save
    @account.account_additional_settings.additional_settings[:delete_spam_days] = 0
    @account.save
    args = { 'account_id' => @account.id, 'ticket_id' => @ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    response = Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(@ticket.id).present?, false
  end

  def test_delete_spam_trash_ticket_without_spam_day_setting
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    Account.current.launch(:delete_trash_daily)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @ticket.deleted = true
    @ticket.updated_at = Time.now - 30.days
    @ticket.save
    @account.account_additional_settings.additional_settings = nil
    @account.save
    args = { 'account_id' => @account.id, 'ticket_id' => @ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    response = Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(@ticket.id).present?, false
  end

  def test_delete_spam_trash_ticket_for_ticket_not_present
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    Account.current.launch(:delete_trash_daily)
    args = { 'account_id' => @account.id, 'ticket_id' => Account.current.tickets.last.id + rand(100),
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    response = Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal response, nil
  end

  def test_delete_spam_trash_ticket_for_undeleted_ticket
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    Account.current.launch(:delete_trash_daily)
    args = { 'account_id' => @account.id, 'ticket_id' => @ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    response = Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(@ticket.id).present?, true
  end
end

require_relative '../unit_test_helper'
class DeleteSpamTrashTicketTest < ActionView::TestCase
  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    Account.current.launch(:delete_trash_daily)
  end

  def teardown
    Helpdesk::Ticket.any_instance.unstub(:deleted)
    Helpdesk::Ticket.any_instance.unstub(:updated_at)
    AwsWrapper::SqsV2.unstub(:send_message)
    Account.unstub(:current)
    super
  end

  class ResponseStub
    def initialize(body, code)
      @body = body
      @code = code
    end
    attr_accessor :body, :code
  end

  class SqsHash
    def initialize(body)
      @body = body.to_json
    end

    def delete
      self.body = {}.to_json
    end
    attr_accessor :body
  end

  def test_delete_spam_trash_ticket_with_spam_day_setting
    @account.account_additional_settings.additional_settings[:delete_spam_days] = 0
    @account.save
    ticket = Account.current.tickets.last
    Helpdesk::Ticket.any_instance.stubs(:deleted).returns(true)
    args = { 'account_id' => @account.id, 'ticket_id' => ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(ticket.id).present?, false
  end

  def test_delete_spam_trash_ticket_without_spam_day_setting
    ticket = Account.current.tickets.last
    Helpdesk::Ticket.any_instance.stubs(:deleted).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:updated_at).returns(Time.now - 30.days)
    @account.account_additional_settings.additional_settings = nil
    @account.save
    args = { 'account_id' => @account.id, 'ticket_id' => ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(ticket.id).present?, false
  end

  def test_delete_spam_trash_ticket_for_ticket_not_present
    args = { 'account_id' => @account.id, 'ticket_id' => Account.current.tickets.last.id + rand(100),
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    response = Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal response, nil
  end

  def test_delete_spam_trash_ticket_for_undeleted_ticket
    ticket = Account.current.tickets.last
    args = { 'account_id' => @account.id, 'ticket_id' => ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    Ryuken::DeleteSpamTrashTicket.new.perform(nil, args)
    assert_equal Account.current.tickets.find_by_id(ticket.id).present?, true
  end

  def test_delete_spam_trash_ticket_requeue
    AwsWrapper::SqsV2.stubs(:send_message).returns(message_id: '1')
    ticket = Account.current.tickets.last
    Helpdesk::Ticket.any_instance.stubs(:deleted).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:updated_at).returns(Time.now - 30.days)
    response_stub = ResponseStub.new({ 'Value' => 20 }.to_json, 429)
    ActiveRecord::Base.current_shard_selection.stubs(:shard).returns(ShardMapping.lookup_with_domain(Account.current.full_domain).shard_name)
    HTTParty.stubs(:get).returns(response_stub)
    args = { 'account_id' => @account.id, 'ticket_id' => ticket.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'ticket_delete_scheduler_type' }
    Ryuken::DeleteSpamTrashTicket.new.perform(SqsHash.new({}), args)
    assert_equal Account.current.tickets.find_by_id(ticket.id).present?, true
  end
end

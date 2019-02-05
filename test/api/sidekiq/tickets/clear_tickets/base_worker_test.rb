require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class BaseWorkerTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include AccountTestHelper

  def setup
    super
    before_all
  end

  def before_all
    if Account.current.nil?
      @user = create_test_account
      @account = @user.account.make_current
      @user.make_current
    else
      @account = Account.current
    end
  end

  def teardown
    super
  end

  # Unit test coverage for app/workers/tickets/clear_tickets/empty_spam.rb ##
  def test_empty_spam_with_clear_all_params
    ticket = create_ticket(account_id: @account.id, spam: true)
    id = ticket.id
    Tickets::ClearTickets::EmptySpam.new.perform('clear_all' => true)
    assert_equal @account.tickets.find_by_id(id), nil
  end

  def test_empty_spam_with_ticket_ids_params
    ticket = create_ticket(account_id: @account.id, spam: true)
    id = ticket.id
    Tickets::ClearTickets::EmptySpam.new.perform('ticket_ids' => [ticket.id])
    assert_equal @account.tickets.find_by_id(id), nil
  end

  def test_empty_spam_with_ticket_nil_params
    ticket = create_ticket(account_id: @account.id, spam: true)
    id = ticket.id
    Tickets::ClearTickets::EmptySpam.new.perform({})
    assert_not_nil @account.tickets.find_by_id(id)
  end

  # Unit test coverage for app/workers/tickets/clear_tickets/empty_trash.rb

  def test_empty_trash_with_clear_all_params
    ticket = create_ticket(account_id: @account.id, deleted: true)
    id = ticket.id
    Tickets::ClearTickets::EmptyTrash.new.perform('clear_all' => true)
    assert_equal @account.tickets.find_by_id(id), nil
  end

  def test_empty_trash_with_ticket_ids_params
    ticket = create_ticket(account_id: @account.id, deleted: true)
    id = ticket.id
    Tickets::ClearTickets::EmptyTrash.new.perform('ticket_ids' => [ticket.id])
    assert_equal @account.tickets.find_by_id(id), nil
  end

  def test_empty_trash_with_ticket_nil_params
    ticket = create_ticket(account_id: @account.id, deleted: true)
    id = ticket.id
    Tickets::ClearTickets::EmptyTrash.new.perform({})
    assert_not_nil @account.tickets.find_by_id(id)
  end

  def test_empty_trash_with_exception
    ticket = create_ticket(account_id: @account.id, deleted: true)
    Account.any_instance.stubs(:tickets).raises(RuntimeError)
    assert_raises(RuntimeError) do
      Tickets::ClearTickets::EmptyTrash.new.perform('clear_all' => true)
    end
    Account.any_instance.unstub(:tickets)
  end
end

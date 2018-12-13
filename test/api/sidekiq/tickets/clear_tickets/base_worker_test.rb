require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
Sidekiq::Testing.fake!
# ['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

class BaseWorkerTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = Account.current.users.first
    User.stubs(:current).returns(@user)
  end

  def teardown
    Account.unstub(:current)
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
    assert_nothing_raised do
      ticket = create_ticket(account_id: @account.id, deleted: true)
      Account.any_instance.stubs(:current).raises(RuntimeError)
      Tickets::ClearTickets::EmptyTrash.new.perform('clear_all' => true)
      Account.any_instance.unstub(:current)
    end
  end
end

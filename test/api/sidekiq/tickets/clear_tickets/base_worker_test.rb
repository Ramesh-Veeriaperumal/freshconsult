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
      if User.current.nil?
        @user = create_dummy_customer
        @user.make_current
      end
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

  def test_emtpy_spam_with_secure_text_field
    Account.any_instance.stubs(:secure_fields_enabled?).returns(true)
    ::Tickets::VaultDataCleanupWorker.jobs.clear
    name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
    secure_text_field = create_custom_field_dn(name, 'secure_text')
    ticket = create_ticket(account_id: @account.id, spam: true)
    id = ticket.id
    Tickets::ClearTickets::EmptySpam.new.perform('ticket_ids' => [id])
    assert_equal @account.tickets.find_by_id(id), nil
    assert_equal 1, ::Tickets::VaultDataCleanupWorker.jobs.size
    args = ::Tickets::VaultDataCleanupWorker.jobs.first.deep_symbolize_keys[:args][0]
    assert_equal [id], args[:object_ids]
    assert_equal 'delete', args[:action]
  ensure
    secure_text_field.destroy
    Account.reset_current_account
    ::Tickets::VaultDataCleanupWorker.jobs.clear
    Account.any_instance.unstub(:secure_fields_enabled?)
  end
end

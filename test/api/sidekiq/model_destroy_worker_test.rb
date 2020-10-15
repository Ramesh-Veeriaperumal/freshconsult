require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!

class ModelDestroyWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper

  def setup
    super
    @account = Account.current || create_account_if_not_exists
  end

  def teardown
    super
  end

  def create_account_if_not_exists
    user = create_test_account
    user.account
  end

  def create_ticket
    create_test_ticket(ticket_params)
  end

  def ticket_params
    {
      email: 'sample@freshdesk.com',
      source: Helpdesk::Source::EMAIL
    }
  end

  def test_delete_model_with_id
    ticket = create_ticket
    assert @account.tickets.find_by_id(ticket.id).present?
    ModelDestroyWorker.new.perform(id: ticket.id, association_with_account: 'tickets')
    assert @account.tickets.find_by_id(ticket.id).nil?
  end

  def test_delete_model_with_invalid_associations
    assert_raises(NoMethodError) do
      ticket = create_ticket
      assert @account.tickets.find_by_id(ticket.id).present?
      ModelDestroyWorker.new.perform(id: ticket.id, association_with_account: 'SOME_RANDOM_TEXT')
    end
  end

  def test_delete_model_with_invalid_id
    assert_raises(ActiveRecord::RecordNotFound) do
      ticket = Account.current.tickets.last
      ticket_id = ticket.present? ? (ticket.id + 100) : 1
      ModelDestroyWorker.new.perform(id: ticket_id, association_with_account: 'tickets')
    end
  end
end

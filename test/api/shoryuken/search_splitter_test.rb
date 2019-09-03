require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
class SearchSplitterTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper

  def teardown
    Account.unstub(:current)
    super
  end

  def test_update_action_runs_write_object
    Account.stubs(:current).returns(Account.first)
    SearchService::Client.any_instance.stubs(:write_object).returns(true)
    SearchService::Client.any_instance.stubs(:delete_object).throws(Exception)
    sqs_msg = {}
    sqs_msg.stubs(:attributes).returns({ SentTimestamp: 100 }.stringify_keys)
    sqs_msg.stubs(:delete).returns(true)
    @account = Account.current
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    args = { object: 'ticket', ticket_properties: { klass_name: @ticket.class.name, account_id: @account.id, document_id: @ticket.id, action: 'update' }.stringify_keys, action_epoch: Time.now.to_i, subscriber_properties: {} }.stringify_keys
    assert_nothing_raised do
      Ryuken::SearchSplitter.new.perform(sqs_msg, args)
    end
  ensure
    SearchService::Client.any_instance.unstub(:write_object)
    SearchService::Client.any_instance.unstub(:delete_object)
  end

  def test_destroy_action_runs_delete_object
    Account.stubs(:current).returns(Account.first)
    SearchService::Client.any_instance.stubs(:write_object).throws(Exception)
    SearchService::Client.any_instance.stubs(:delete_object).returns(true)
    sqs_msg = {}
    sqs_msg.stubs(:attributes).returns({ SentTimestamp: 100 }.stringify_keys)
    sqs_msg.stubs(:delete).returns(true)
    @account = Account.current
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    args = { object: 'ticket', ticket_properties: { klass_name: @ticket.class.name, account_id: @account.id, document_id: @ticket.id, action: 'destroy' }.stringify_keys, action_epoch: Time.now.to_i, subscriber_properties: {} }.stringify_keys
    assert_nothing_raised do
      Ryuken::SearchSplitter.new.perform(sqs_msg, args)
    end
  ensure
    SearchService::Client.any_instance.unstub(:write_object)
    SearchService::Client.any_instance.unstub(:delete_object)
  end

  def test_should_raise_exception_if_object_properties_not_specified
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    args = { object: 'ticket', ticket_properties: {}, action_epoch: Time.now.to_i, subscriber_properties: {} }.stringify_keys
    assert_raise(NoMethodError) do
      Ryuken::SearchSplitter.new.perform(nil, args)
    end
  end
end

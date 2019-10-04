require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

class TicketBodyJobsTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def tear_down
    Account.unstub(:current)
  end

  def test_push_to_S3
    ticket = create_ticket(account_id: @account.id)
    file_path = Helpdesk::S3::Ticket::Body.generate_file_path(@account.id, ticket.id)
    bucket_name = S3_CONFIG[:ticket_body]
    ticket_body = Helpdesk::TicketOldBody.find_by_ticket_id_and_account_id(ticket.id, @account.id)
    value = ticket_body.try(:attributes).to_json
    mock = MiniTest::Mock.new
    mock.expect(:call, AWS::S3::Bucket.new(bucket_name).objects[file_path], [file_path, value, bucket_name])
    Helpdesk::S3::Ticket::Body.stub(:create, mock) do
      Tickets::TicketBodyJobs.new.perform(key_id: ticket.id)
    end
    mock.verify
    ticket.destroy
  end

  def test_delete_file_from_S3
    ticket = create_ticket(account_id: @account.id)
    mock = MiniTest::Mock.new
    mock.expect(:call, nil, [Helpdesk::S3::Ticket::Body.generate_file_path(@account.id, ticket.id), S3_CONFIG[:ticket_body]])
    Helpdesk::S3::Ticket::Body.stub(:delete, mock) do
      Tickets::TicketBodyJobs.new.perform(key_id: ticket.id, delete: true)
    end
    mock.verify
    ticket.destroy
  end

  def test_push_to_S3_with_exception
    ticket = create_ticket(account_id: @account.id)
    Helpdesk::TicketOldBody.any_instance.stubs(:attributes).raises(RuntimeError)
    assert_nothing_raised do
      Tickets::TicketBodyJobs.new.perform(key_id: ticket.id)
    end
    Helpdesk::TicketOldBody.any_instance.unstub(:attributes)
    ticket.destroy
  end
end

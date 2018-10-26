require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')


class DeleteArchiveTicketTest < ActionView::TestCase
  include AccountTestHelper

  def teardown
    Account.unstub(:current)
    super
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_delete_archive_worker 
      archive_note_ids = [234,235,236]
      delete_worker = Archive::DeleteArchiveTicket.new
      ticket_mock = MiniTest::Mock.new
      note_mock = MiniTest::Mock.new
      ticket_mock.expect(:call, nil, [S3_CONFIG[:archive_ticket_body], Helpdesk::S3::ArchiveTicket::Body.generate_file_path(@account.id, 75)])      
      note_mock.expect(:call, nil, [S3_CONFIG[:archive_note_body], generate_s3_note_keys(archive_note_ids)])
      AwsWrapper::S3.stub(:delete, ticket_mock) do
        AwsWrapper::S3.stub(:batch_delete, note_mock) do
          delete_worker.perform({:ticket_id => 75, :note_ids => archive_note_ids})      
        end
      end
      note_mock.verify      
      ticket_mock.verify
  end

  def test_delete_archive_worker_without_coversations
      delete_worker = Archive::DeleteArchiveTicket.new      
      mock = MiniTest::Mock.new
      mock.expect(:call, nil, [S3_CONFIG[:archive_ticket_body], Helpdesk::S3::ArchiveTicket::Body.generate_file_path(@account.id, 76)])
      AwsWrapper::S3.stub(:delete, mock) do
        delete_worker.perform({:ticket_id => 76 , :note_ids => []})        
      end
      mock.verify                
  end

  private

  def generate_s3_note_keys(note_ids)
    keys = Array.new
    note_ids.each do |note_id|
      keys << Helpdesk::S3::ArchiveNote::Body.generate_file_path(@account.id, note_id)
    end
    keys
  end
end
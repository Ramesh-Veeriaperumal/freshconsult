require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'note_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

class NoteBodyJobsTest < ActionView::TestCase
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
    note = create_note(ticket_id: ticket.id, source: 0)
    file_path = Helpdesk::S3::Note::Body.generate_file_path(@account.id, note.id)
    bucket_name = S3_CONFIG[:note_body]
    note_body = Helpdesk::NoteOldBody.find_by_note_id_and_account_id(note.id, @account.id)
    value = note_body.attributes.to_json
    mock = MiniTest::Mock.new
    mock.expect(:call, AWS::S3::Bucket.new(bucket_name).objects[file_path], [file_path, value, bucket_name])
    Helpdesk::S3::Note::Body.stub(:create, mock) do
      Notes::NoteBodyJobs.new.perform(key_id: note.id)
    end
    mock.verify
    note.destroy
    ticket.destroy
  end

  def test_delete_file_from_S3
    ticket = create_ticket(account_id: @account.id)
    note = create_note(ticket_id: ticket.id, source: 0)
    mock = MiniTest::Mock.new
    mock.expect(:call, nil, [Helpdesk::S3::Note::Body.generate_file_path(@account.id, note.id), S3_CONFIG[:note_body]])
    Helpdesk::S3::Note::Body.stub(:delete, mock) do
      Notes::NoteBodyJobs.new.perform(key_id: note.id, delete: true)
    end
    mock.verify
    note.destroy
    ticket.destroy
  end

  def test_push_to_S3_with_exception
    ticket = create_ticket(account_id: @account.id)
    note = create_note(ticket_id: ticket.id, source: 0)
    Helpdesk::NoteOldBody.any_instance.stubs(:attributes).raises(RuntimeError)
    assert_nothing_raised do
      Notes::NoteBodyJobs.new.perform(key_id: note.id)
    end
    Helpdesk::NoteOldBody.any_instance.unstub(:attributes)
    note.destroy
    ticket.destroy
  end
end

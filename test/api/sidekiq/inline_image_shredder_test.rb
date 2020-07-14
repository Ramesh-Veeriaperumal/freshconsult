require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'minitest'

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'attachments_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

Sidekiq::Testing.fake!

class InlineImageShredderTest < ActionView::TestCase
  include CoreTicketsTestHelper
  include AttachmentsTestHelper
  include NoteTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    InlineImageShredder.jobs.clear
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def create_archive_ticket_with_id(ticket_id)
    Sidekiq::Testing.inline! do
      Archive::TicketWorker.perform_async(account_id: @account.id, ticket_id: ticket_id)
    end
  end

  def create_attachment_for_account(attachable, attachable_type = nil)
    attachment = @account.attachments.new
    attachment.description = 'abcx'
    attachment.attachable_id = attachable.id
    attachment.attachable_type = attachable_type || (attachable.is_a?(Helpdesk::Note) ? 'Note::Inline' : 'Ticket::Inline')
    attachment.content_file_name = 'testattach'
    attachment.content_content_type = 'text/binary'
    attachment.content_file_size = 80
    attachment.save
    return attachment.id
  end

  def construct_args(archive_ticket)
    {
      model_name: 'Helpdesk::ArchiveTicket',
      model_id: archive_ticket.id
    }
  end

  def test_inline_image_shredder_worker_runs
    requester = @account.users.first
    ticket = create_ticket(requester_id: requester.id)
    create_archive_ticket_with_id(ticket.id)
    args = construct_args(ticket)
    InlineImageShredder.new.perform(args)
    assert_equal 0, InlineImageShredder.jobs.size
  end

  def test_inline_image_shredder_worker_runs_with_attachments_present
    requester = @account.users.first
    ticket = create_ticket(requester_id: requester.id)
    create_archive_ticket_with_id(ticket.id)
    args = construct_args(ticket)
    inline_attachment_ids = []
    inline_attachment_ids << create_attachment_for_account(ticket)
    InlineImageShredder.any_instance.stubs(:get_attachment_ids).returns(inline_attachment_ids)
    InlineImageShredder.new.perform(args)
    @account.reload
    assert_empty @account.attachments.where(id: inline_attachment_ids)
    assert_equal 0, InlineImageShredder.jobs.size
  ensure
    InlineImageShredder.any_instance.unstub(:get_attachment_ids)
  end
  
  def test_inline_image_shredder_worker_errors_out_without_body_content
    AwsWrapper::S3Object.stubs(:delete).raises(AWS::S3::Errors::NoSuchKey.new('test', 'test'))
    DeletedBodyObserver.any_instance.stubs(:cleanup_file_path).returns('my_dummy_path')
    requester = @account.users.first
    ticket = create_ticket(requester_id: requester.id)
    create_archive_ticket_with_id(ticket.id)
    args = construct_args(ticket)
    InlineImageShredder.new.perform(args)
    assert_equal 0, InlineImageShredder.jobs.size
  end

  def test_inline_image_shredder_worker_with_inline_attachments
    requester = @account.users.first
    attachment_id = create_attachment_for_account(requester)
    token = @account.attachments.find(attachment_id).encoded_token
    content = "<div>Hello</div><div><img src='https://localhost.freshdesk-dev.com/attachments?token=#{token}' alt='test'></div>"
    AwsWrapper::S3Object.stubs(:exists?).returns(true)
    AwsWrapper::S3Object.stubs(:read).returns(content)
    args = {
      model_name: 'Helpdesk::Note',
      model_id: @account.notes.last.id
    }
    InlineImageShredder.new.perform(args)
    assert_equal 0, InlineImageShredder.jobs.size
  end

  def test_inline_image_shredder_worker_with_inline_attachments_without_token
    content = "<div>Hello</div><div><img src='https://localhost.freshdesk-dev.com/attachments?test=1' alt='test'></div>"
    AwsWrapper::S3Object.stubs(:exists?).returns(true)
    AwsWrapper::S3Object.stubs(:read).returns(content)
    args = {
      model_name: 'Helpdesk::Note',
      model_id: @account.notes.last.id
    }
    InlineImageShredder.new.perform(args)
    assert_equal 0, InlineImageShredder.jobs.size
  end

  def test_inline_image_shredder_worker_with_inline_attachments_not_belonging_to_note
    requester = @account.users.first
    note1 = create_note(user_id: requester.id)
    note2 = create_note(user_id: requester.id)
    inline_attachment_id1 = create_attachment_for_account(note1)
    inline_attachment_id2 = create_attachment_for_account(note2)
    inline_attachment_ids = []
    inline_attachment_ids << inline_attachment_id1
    inline_attachment_ids << inline_attachment_id2 # extra note id
    args = {
      model_name: 'Helpdesk::Note',
      model_id: note1.id
    }
    InlineImageShredder.any_instance.stubs(:get_attachment_ids).returns(inline_attachment_ids)
    InlineImageShredder.new.perform(args)
    @account.reload
    assert_empty @account.attachments.where(id: inline_attachment_id1)
    assert_present @account.attachments.where(id: inline_attachment_id2)
    assert_equal 0, InlineImageShredder.jobs.size
  ensure
    InlineImageShredder.any_instance.unstub(:get_attachment_ids)
  end

  def test_inline_image_shredder_worker_with_inline_attachments_not_belonging_to_ticket
    requester = @account.users.first
    ticket1 = create_ticket(requester_id: requester.id)
    ticket2 = create_ticket(requester_id: requester.id)
    inline_attachment_id1 = create_attachment_for_account(ticket1)
    inline_attachment_id2 = create_attachment_for_account(ticket2)
    inline_attachment_ids = []
    inline_attachment_ids << inline_attachment_id1
    inline_attachment_ids << inline_attachment_id2 # extra ticket id
    args = {
      model_name: 'Helpdesk::Ticket',
      model_id: ticket1.id
    }
    InlineImageShredder.any_instance.stubs(:get_attachment_ids).returns(inline_attachment_ids)
    InlineImageShredder.new.perform(args)
    @account.reload
    assert_empty @account.attachments.where(id: inline_attachment_id1)
    assert_present @account.attachments.where(id: inline_attachment_id2)
    assert_equal 0, InlineImageShredder.jobs.size
  ensure
    InlineImageShredder.any_instance.unstub(:get_attachment_ids)
  end

  def test_inline_image_shredder_worker_type_tickets_image_upload
    requester = @account.users.first
    ticket = create_ticket(requester_id: requester.id)
    inline_attachment_id = create_attachment_for_account(ticket, 'Tickets Image Upload')
    inline_attachment_ids = []
    inline_attachment_ids << inline_attachment_id
    args = {
      model_name: 'Helpdesk::Ticket',
      model_id: ticket.id
    }
    InlineImageShredder.any_instance.stubs(:get_attachment_ids).returns(inline_attachment_ids)
    InlineImageShredder.new.perform(args)
    @account.reload
    assert_empty @account.attachments.where(id: inline_attachment_ids)
    assert_equal 0, InlineImageShredder.jobs.size
  ensure
    InlineImageShredder.any_instance.unstub(:get_attachment_ids)
  end
end

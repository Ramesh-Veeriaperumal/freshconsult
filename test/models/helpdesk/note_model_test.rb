require_relative '../test_helper'
require_relative '../../api/unit_test_helper'
require_relative '../../../spec/support/note_helper'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../api/helpers/tickets_test_helper.rb'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class NoteModelTest < ActiveSupport::TestCase
  include AccountHelper
  include EmailHelper
  include NoteHelper
  include UsersHelper
  include TicketsTestHelper

  def setup
    @account = create_test_account if @account.nil?
    @account.make_current
  end

  def teardown
    super
  end

  def test_email_agent_as_requester
    @account = Account.current
    @agent = add_agent(Account.current)
    ticket = create_ticket(requester_id: @agent.id)
    test_note = FactoryGirl.build(:helpdesk_note, source: 2,
                                                  notable_id: ticket.id,
                                                  user_id: @agent.id,
                                                  account_id: @account.id,
                                                  notable_type: 'Helpdesk::Ticket')
    test_note.incoming = false
    test_note.private = true
    test_note.build_note_body(body: Faker::Lorem.paragraph, body_html: Faker::Lorem.paragraph)

    test_note.expects(:handle_notification_for_agent_as_req).times(1)
    test_note.expects(:integrations_private_note_notifications).times(0)

    test_note.save_note
  end

  def test_update_email_received_at_note
    time = Time.zone.now.to_s
    parsed_date = parse_internal_date(time)
    @account = Account.current
    Helpdesk::Note.any_instance.stubs(:schema_less_note).returns(Helpdesk::SchemaLessNote.new)
    note = create_note
    note.update_email_received_at(parsed_date)
    assert_equal true, note.schema_less_note.note_properties.key?(:received_at)
  end

  # Replacing the cid for all places using gsub is the fix.
  def test_content_id_for_more_than_one_inline_image_is_same_then_all_images_should_display
    ticket = Account.current.tickets.last
    attachment = Helpdesk::Attachment.new
    attachment.attachable_type = 'Ticket::Inline'
    attachment.content_file_name = 'testattach'
    attachment.content_content_type = 'text/binary'
    attachment.content_file_size = 80
    Helpdesk::Note.any_instance.stubs(:inline_attachments).returns([attachment])
    note = create_note(notable_id: ticket.id, private: false)
    note.note_body.body_html = "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    note.note_body.full_text_html = "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    note.header_info = { content_ids: { note.inline_attachments[0].content_file_name + '0' => 'abc' } }
    note.safe_send(:update_content_ids)
    assert_not_equal note.note_body.body_html, "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    assert_not_equal note.note_body.full_text_html, "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    Helpdesk::Note.any_instance.unstub(:inline_attachments)
  end

  def test_update_sender_email_for_ticket_on_create_note
    @account = Account.current
    user = add_new_user(@account)
    ticket = create_ticket(requester_id: user.id)
    assert_equal user.email, ticket.from_email
    email = Faker::Internet.email
    user.email = email
    user.save!
    note = create_note(ticket_id: ticket.id, source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'], incoming: false, user_id: user.id)
    ticket.reload
    assert_equal email, note.notable.sender_email
    assert_equal email, ticket.from_email
  end
end

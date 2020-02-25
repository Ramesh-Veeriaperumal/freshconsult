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
end

require_relative '../../api/unit_test_helper'
require_relative '../../../spec/support/note_helper'

class NoteModelTest < ActiveSupport::TestCase
  include EmailHelper
  include NoteHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
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
end

require_relative '../../test_helper'

class NoteTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include NotesTestHelper
  include AttachmentsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:note_central_publish)
    @ticket = create_ticket
    @@before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    @account.rollback(:note_central_publish)
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note = create_note(note_params_hash)
    assert_equal 0, CentralPublishWorker::ActiveNoteWorker.jobs.size
  ensure
    @account.launch(:note_central_publish)
  end

  def test_central_publish_with_launch_party_enabled
  	CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note = create_note(note_params_hash)
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
  end

  def test_central_publish_payload
    note = create_note(note_params_hash)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
    assoc_payload = note.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  end

  def test_central_publish_update_action
    note = create_note(note_params_hash)
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note.update_attributes(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"])
    note.reload
    payload = note.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_note_pattern(note))
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    assert_equal 'note_update', job['args'][0]
    assert_equal({"note_type"=>"public"}, job['args'][1]['model_changes'])
  end

end

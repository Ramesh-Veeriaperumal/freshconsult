require_relative '../../test_helper'

class SourceTest < ActionView::TestCase
  def test_ticket_source_options
    assert_equal TicketConstants::SOURCE_OPTIONS, Helpdesk::Source.ticket_source_options
  end

  def test_ticket_source_names_by_key
    assert_equal TicketConstants::SOURCE_NAMES_BY_KEY, Helpdesk::Source.ticket_source_names_by_key
  end

  def test_ticket_source_keys_by_token
    assert_equal TicketConstants::SOURCE_KEYS_BY_TOKEN, Helpdesk::Source.ticket_source_keys_by_token
  end

  def test_ticket_source_keys_by_name
    assert_equal TicketConstants::SOURCE_KEYS_BY_NAME, Helpdesk::Source.ticket_source_keys_by_name
  end

  def test_ticket_source_token_by_key
    assert_equal TicketConstants::SOURCE_TOKEN_BY_KEY, Helpdesk::Source.ticket_source_token_by_key
  end

  def test_ticket_sources_for_language_detection
    assert_equal TicketConstants::SOURCES_FOR_LANG_DETECTION, Helpdesk::Source.ticket_sources_for_language_detection
  end

  def note_source_keys_by_token
    assert_equal Helpdesk::Note::SOURCE_KEYS_BY_TOKEN, Helpdesk::Source.note_source_keys_by_token
  end

  def test_ticket_note_source_mapping
    assert_equal Helpdesk::Note::TICKET_NOTE_SOURCE_MAPPING, Helpdesk::Source.ticket_note_source_mapping
  end

  def test_ticket_sources
    assert_equal TicketConstants::SOURCES, Helpdesk::Source.ticket_sources
  end

  def test_note_sources
    assert_equal Helpdesk::Note::SOURCES, Helpdesk::Source.note_sources
  end

  def test_ticket_bot_source
    assert_equal TicketConstants::BOT_SOURCE, Helpdesk::Source.ticket_bot_source
  end

  def test_note_source_names_by_key
    assert_equal Helpdesk::Note::SOURCE_NAMES_BY_KEY, Helpdesk::Source.note_source_names_by_key
  end

  def test_note_activities_hash
    assert_equal Helpdesk::Note::ACTIVITIES_HASH, Helpdesk::Source.note_activities_hash
  end

  def test_api_sources
    assert_equal ApiTicketConstants::SOURCES, Helpdesk::Source.api_sources
  end

  def test_api_unpermitted_sources_for_update
    assert_equal ApiTicketConstants::UNPERMITTED_SOURCES_FOR_UPDATE, Helpdesk::Source.api_unpermitted_sources_for_update
  end

  def test_note_exclude_sources
    assert_equal Helpdesk::Note::EXCLUDE_SOURCE, Helpdesk::Source.note_exclude_sources
  end

  def test_note_blacklisted_thank_you_detector_note_sources
    assert_equal Helpdesk::Note::BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES, Helpdesk::Source.note_blacklisted_thank_you_detector_note_sources
  end
end

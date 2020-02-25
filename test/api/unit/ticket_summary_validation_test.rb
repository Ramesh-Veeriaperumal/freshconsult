require_relative '../unit_test_helper'

class TicketSummaryValidationTest < ActionView::TestCase

  def test_numericality
    controller_params = { 'user_id' => 1,  body: Faker::Lorem.paragraph }
    item = nil
    ticket_summary = TicketSummaryValidation.new(controller_params, item)
    assert ticket_summary.valid?(:update)
  end

  def test_body
    controller_params = { 'user_id' => 1 }
    item = Helpdesk::Note.new
    item.note_body.body = ''
    item.note_body.body_html = 'test'
    ticket_summary = TicketSummaryValidation.new(controller_params, item)
    assert ticket_summary.valid?(:update)

    controller_params = { 'user_id' => 1, body: true }
    item = nil
    ticket_summary = TicketSummaryValidation.new(controller_params, item)
    refute ticket_summary.valid?(:update)
    assert ticket_summary.errors.full_messages.include?('Body datatype_mismatch')
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { 'user_id' => 1, attachments: ['file.png'],  body: Faker::Lorem.paragraph }
    item = nil
    ticket_summary = TicketSummaryValidation.new(controller_params, item)
    refute ticket_summary.valid?(:update)
    errors = ticket_summary.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({ body: {}, user_id: {}, attachments: { expected_data_type: 'valid file format' } },
                 ticket_summary.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_validate_cloud_files
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => Faker::Lorem.word }
    ticket_summary = TicketSummaryValidation.new(controller_params, nil)
    refute ticket_summary.valid?(:update)
    errors = ticket_summary.errors.full_messages
    assert errors.include?('Cloud files datatype_mismatch')

    controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => [{'filename' => Faker::Lorem.word}] }
    ticket_summary = ConversationValidation.new(controller_params, nil)
    refute ticket_summary.valid?(:update)
    errors = ticket_summary.errors.full_messages
    assert errors.include?('Cloud files is invalid')
    Account.unstub(:current)
  end

end

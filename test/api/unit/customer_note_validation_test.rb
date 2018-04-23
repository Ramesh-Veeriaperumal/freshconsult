require_relative '../unit_test_helper'

class CustomerNoteValidationTest < ActionView::TestCase
  def test_success
    controller_params = {
      title: Faker::Lorem.characters(30),
      body: Faker::Lorem.paragraph
    }
    item = nil
    note = CustomerNoteValidation.new(controller_params, item)
    assert note.valid?(:create)
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { attachments: ['file.png'], body: Faker::Lorem.paragraph }
    item = nil
    note = CustomerNoteValidation.new(controller_params, item)
    refute note.valid?
    errors = note.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({ attachments: { expected_data_type: 'valid file format' } }, note.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    TicketsValidationHelper.unstub(:attachment_size)
  end

  # def test_validate_cloud_files
  #   controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => Faker::Lorem.word }
  #   note = CustomerNoteValidation.new(controller_params, nil)
  #   refute note.valid?(:create)
  #   errors = note.errors.full_messages
  #   assert errors.include?('Cloud files datatype_mismatch')
  #
  #   controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => [{'filename' => Faker::Lorem.word}] }
  #   note = CustomerNoteValidation.new(controller_params, nil)
  #   refute note.valid?(:create)
  #   errors = note.errors.full_messages
  #   assert errors.include?('Cloud files is invalid')
  # end
end

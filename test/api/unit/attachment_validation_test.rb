require_relative '../unit_test_helper'

class AttachmentValidationTest < ActionView::TestCase

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_numericality
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'user_id' => 1,  content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)

    controller_params = { 'user_id' => 'ABC',  content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('User datatype_mismatch')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_content
    controller_params = { 'user_id' => 1,  content: 'ABC' }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content datatype_mismatch')

    controller_params = { 'user_id' => 1,  content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    FileSizeValidator.any_instance.stubs(:current_size).returns(20_000_000)
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    FileSizeValidator.any_instance.unstub(:current_size)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content invalid_size')

    controller_params = { 'user_id' => 1,  content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_incompatible_fields
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'user_id' => 1,  content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: true, 'inline_type' => 1 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('User cannot_set_user_id')

    controller_params = { 'user_id' => 1,  content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), 'inline_type' => 5 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type cannot_set_inline_type')

    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: true }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type missing_field')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_invalid_inline_file_type
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { content: fixture_file_upload('files/attachment.txt', 'plain/text'), inline: true, 'inline_type' => 1 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content invalid_image_file')

    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: 'true', 'inline_type' => 100 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type not_included')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_inline_image_upload
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: 'true', 'inline_type' => 2 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end
end

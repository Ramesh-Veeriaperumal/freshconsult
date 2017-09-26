require_relative '../unit_test_helper'

class ProductFeedbackValidationTest < ActionView::TestCase
  def test_empty_body
    product_feedback_validation = ProductFeedbackValidation.new({}, nil)
    refute product_feedback_validation.valid?
    errors = product_feedback_validation.errors.full_messages
    assert errors.include?("Description can't be blank")
  end

  def test_empty_description
    product_feedback_validation = ProductFeedbackValidation.new({ description: '' }, nil)
    refute product_feedback_validation.valid?
    errors = product_feedback_validation.errors.full_messages
    assert errors.include?("Description can't be blank")
  end

  def test_feedback_with_valid_description
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence }, nil)
    assert product_feedback_validation.valid?
  end

  def test_feedback_with_invalid_subject
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, subject: rand(100_000) }, nil)
    refute product_feedback_validation.valid?
    errors = product_feedback_validation.errors.full_messages
    assert errors.include?('Subject datatype_mismatch')
  end

  def test_feedback_with_valid_subject
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, subject: Faker::Lorem.sentence }, nil)
    assert product_feedback_validation.valid?
  end

  def test_feedback_with_invalid_attachment_ids
    attachment_ids = Faker::Lorem.sentence.split.map(&:length)
    rand(1..5).times { attachment_ids << Faker::Lorem.word }
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, attachment_ids: attachment_ids }, nil)
    refute product_feedback_validation.valid?
    errors = product_feedback_validation.errors.full_messages
    assert errors.include?('Attachment ids array_datatype_mismatch')
  end

  def test_feedback_with_valid_attachment_ids
    attachment_ids = Faker::Lorem.sentence.split.map(&:length)
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, attachment_ids: attachment_ids }, nil)
    assert product_feedback_validation.valid?
  end

  def test_feedback_with_invalid_tags
    tags = Faker::Lorem.sentence.split
    rand(3..10).times { tags << rand(100_000) }
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, tags: tags }, nil)
    refute product_feedback_validation.valid?
    errors = product_feedback_validation.errors.full_messages
    assert errors.include?('Tags array_datatype_mismatch')
  end

  def test_feedback_with_valid_tags
    tags = Faker::Lorem.sentence.split
    product_feedback_validation = ProductFeedbackValidation.new({ description: Faker::Lorem.sentence, tags: tags }, nil)
    assert product_feedback_validation.valid?
  end

  def test_valid_feedback_with_all_fields
    product_feedback_validation = ProductFeedbackValidation.new(
      {
        subject: Faker::Lorem.sentence,
        description: Faker::Lorem.sentence,
        attachment_ids: Faker::Lorem.sentence.split.map(&:length),
        tags: Faker::Lorem.sentence.split
      }, nil
    )
    assert product_feedback_validation.valid?
  end
end

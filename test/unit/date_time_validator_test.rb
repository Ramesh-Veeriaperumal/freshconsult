require_relative '../test_helper'

class DateTimeValidatorTest < ActionView::TestCase
  def test_valid_date_time
    date_time_validator = DateTimeValidator.new(allow_nil: true, fields: [:created_at, :updated_at])
    topic = ApiDiscussions::TopicValidation.new({}, nil)
    topic.created_at = Time.zone.now.to_s
    topic.updated_at = Time.zone.now.to_s
    date_time_validator.validate(topic)
    assert topic.errors.empty?
  end

  def test_invalid_date_time
    date_time_validator = DateTimeValidator.new(allow_nil: true, fields: [:created_at, :updated_at])
    topic = ApiDiscussions::TopicValidation.new({}, nil)
    topic.created_at = 'test'
    topic.updated_at = Time.zone.now.to_s
    date_time_validator.validate(topic)
    refute topic.errors.empty?
    refute topic.errors.full_messages.include?('Updated at is not a date')
    assert topic.errors.full_messages.include?('Created at is not a date')
  end

  def test_valid_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: true, fields: [:created_at, :updated_at])
    topic = ApiDiscussions::TopicValidation.new({}, nil)
    topic.created_at = nil
    date_time_validator.validate(topic)
    assert topic.errors.empty?
  end

  def test_invalid_empty_string_for_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: true, fields: [:created_at, :updated_at])
    topic = ApiDiscussions::TopicValidation.new({}, nil)
    topic.created_at = ''
    date_time_validator.validate(topic)
    refute topic.errors.empty?
    assert topic.errors.full_messages.include?('Created at is not a date')
  end

  def test_invalid_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: false, fields: [:created_at, :updated_at])
    topic = ApiDiscussions::TopicValidation.new({}, nil)
    date_time_validator.validate(topic)
    refute topic.errors.empty?
    assert_equal ['Created at is not a date', 'Updated at is not a date'], topic.errors.full_messages
  end
end

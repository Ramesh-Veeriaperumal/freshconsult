require_relative '../../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

module Pipe
  class ConversationValidationTest < ::ConversationValidationTest
    def test_create_with_created_at_updated_at
      Account.stubs(:current).returns(Account.first)
      time_now = Time.now
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      assert conversation.valid?(:create)
    end

    def test_created_at_string
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => 'string', 'updated_at' => Time.now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Created at invalid_date')
      Account.unstub(:current)
    end

    def test_created_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => nil, 'updated_at' => Time.now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_updated_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => Time.now, 'updated_at' => nil }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_updated_at_created_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => nil, 'updated_at' => nil }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_created_at_without_updated_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => Time.now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert_equal({
                     body: {}, user_id: {},
                     created_at: { dependent_timestamp: :updated_at, code: :missing_field }
                   }, conversation.error_options)
      Account.unstub(:current)
    end

    def test_updated_at_without_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'updated_at' => Time.now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      assert_equal({
                     body: {}, user_id: {},
                     updated_at: { dependent_timestamp: :created_at, code: :missing_field }
                   }, conversation.error_options)
      Account.unstub(:current)
    end

    def test_created_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => (Time.now + 10.minutes),
                            'updated_at' => Time.now }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Created at start_time_lt_now')
      Account.unstub(:current)
    end

    def test_updated_at_lt_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => Time.now,
                            'updated_at' => (Time.now - 10.minutes) }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Updated at gt_created_and_now')
      Account.unstub(:current)
    end

    def test_updated_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { :user_id => 1, :body => Faker::Lorem.paragraph,
                            'created_at' => Time.now - 10.minutes,
                            'updated_at' => (Time.now + 10.minutes) }
      item = nil
      conversation = ConversationValidation.new(controller_params, item)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Updated at start_time_lt_now')
      Account.unstub(:current)
    end
  end
end

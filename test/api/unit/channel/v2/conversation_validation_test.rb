require_relative '../../../unit_test_helper'
require_relative '../../conversation_validation_test.rb'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

module Channel::V2
  class ConversationValidationTest < ConversationValidationTest
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

    def test_twitter_dm_as_note
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'dm',
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      assert conversation.valid?(:create)
      Account.unstub(:current)
    end

    def test_twitter_mention_as_note
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'mention',
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id:Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      assert conversation.valid?(:create)
      Account.unstub(:current)
    end

    def test_twitter_tweet_type_not_present
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter datatype_mismatch')
      Account.unstub(:current)
    end

    def test_twitter_invalid_tweet_type
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'post',
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter not_included')
      Account.unstub(:current)
    end

    def test_twitter_tweet_id_not_present
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: { 
          tweet_type: 'mention',
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter datatype_mismatch')
      Account.unstub(:current)
    end

    def test_twitter_stream_id_not_present
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'dm',
          support_handle_id: Faker::Number.number(4).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter datatype_mismatch')
      Account.unstub(:current)
    end

    def test_twitter_invalid_support_handle_id
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 5,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'mention',
          support_handle_id: true,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter datatype_mismatch')
      Account.unstub(:current)
    end

    def test_twitter_ticket_invalid_source_type
      Account.stubs(:current).returns(Account.first)
      controller_params = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: false,
        source: 2,
        twitter: {
          tweet_id: Faker::Number.number(3).to_i,
          tweet_type: 'mention',
          support_handle_id: Faker::Number.number(4).to_i,
          stream_id: Faker::Number.number(3).to_i
        }
      }
      conversation = ConversationValidation.new(controller_params, nil)
      refute conversation.valid?(:create)
      errors = conversation.errors.full_messages
      assert errors.include?('Twitter invalid_field')
      Account.unstub(:current)
    end
  end
end

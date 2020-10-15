# frozen_string_literal: true

require_relative '../test_helper'
require 'faker'
require Rails.root.join('spec', 'support', 'account_helper.rb')

module Sqs
  class FacebookMessageTest < ActiveSupport::TestCase
    def setup
      @account = Account.first || create_test_account
      Account.any_instance.stubs(:current).returns(@account)
      super
    end

    def teardown
      Account.any_instance.unstub(:current)
      super
    end

    def default_message(options = {})
      {
        entry: {
          id: options[:fb_page_id] || Faker::Number.number(5),
          messaging: options[:messaging] || Faker::Lorem.paragraph,
          account_id: Account.current.id
        }
      }
    end

    def test_facebook_message_with_validity_nil
      options = {}
      options[:fb_page_id] = Faker::Number.number(5)
      options[:messaging] = Faker::Lorem.paragraph
      message = default_message(options).to_json
      Facebook::Core::Message.any_instance.stubs(:account_and_page_validity).returns(nil)
      fb_message_obj = Sqs::FacebookMessage.new(message)
      Rails.logger.expects(:debug).with("Invalid validity for page id: #{options[:fb_page_id]}, account_id: #{Account.current.id}, message: #{options[:messaging]}")
      fb_message_obj.process
    ensure
      Facebook::Core::Message.unstub(:account_and_page_validity)
    end

    def test_facebook_message_with_validity_not_hash
      options = {}
      options[:fb_page_id] = Faker::Number.number(5)
      options[:messaging] = Faker::Lorem.paragraph
      message = default_message(options).to_json
      Facebook::Core::Message.any_instance.stubs(:account_and_page_validity).returns(true)
      fb_message_obj = Sqs::FacebookMessage.new(message)
      Rails.logger.expects(:debug).with("Invalid validity for page id: #{options[:fb_page_id]}, account_id: #{Account.current.id}, message: #{options[:messaging]}")
      fb_message_obj.process
    ensure
      Facebook::Core::Message.unstub(:account_and_page_validity)
    end
  end
end

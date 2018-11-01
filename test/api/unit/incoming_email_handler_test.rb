require_relative '../../test_helper'
module Helpdesk
  module Email
    class IncomingEmailHandlerTest < ActionView::TestCase
      def setup
        @from_email = Faker::Internet.email
        @to_email = Faker::Internet.email
      end

      def test_message_id
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_front_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "message-id: #{id}\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_front_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "message-id: <#{id}>\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_xmstnefcorrelator_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "x-ms-tnef-correlator:     #{id}\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_xmstnefcorrelator_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "x-ms-tnef-correlator: <#{id}>\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_middle_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\rmessage-id:  #{id}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_middle_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\rmessage-id: <#{id}>, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end
    end
  end
end

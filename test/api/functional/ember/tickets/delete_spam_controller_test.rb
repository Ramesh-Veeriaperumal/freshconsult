require_relative '../../../test_helper'
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Tickets
    class DeleteSpamControllerTest < ActionController::TestCase
      include TicketHelper

      def wrap_cname(params)
        { delete_spam: params }
      end

      def test_empty_trash
        delete :empty_trash, construct_params({ version: 'private' }, {})
        assert_response 204
      end

      def test_empty_spam
        delete :empty_spam, construct_params({ version: 'private' }, {})
        assert_response 204
      end

      def test_delete_forever_with_no_params
        put :delete_forever, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json([bad_request_error_pattern('ids', :missing_field)])
      end

      def test_delete_forever_with_invalid_tickets
        ticket_ids = []
        rand(5..10).times do
          ticket_ids << create_ticket.id
        end
        invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
        put :delete_forever, construct_params({ version: 'private' }, {ids: [*ticket_ids, *invalid_ids]})
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
        invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern([], failures))
      end

      def test_delete_forever_success
        ticket_ids = []
        rand(5..10).times do
          ticket_ids << create_ticket(deleted: true).id
        end
        put :delete_forever, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_delete_forever_spam_with_no_params
        put :delete_forever_spam, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json([bad_request_error_pattern('ids', :missing_field)])
      end

      def test_delete_forever_spam_with_invalid_tickets
        ticket_ids = []
        rand(5..10).times do
          ticket_ids << create_ticket.id
        end
        invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
        put :delete_forever_spam, construct_params({ version: 'private' }, {ids: [*ticket_ids, *invalid_ids]})
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
        invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern([], failures))
      end

      def test_delete_forever_spam_success
        ticket_ids = []
        rand(5..10).times do
          ticket_ids << create_ticket(spam: true).id
        end
        put :delete_forever_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

    end
  end
end

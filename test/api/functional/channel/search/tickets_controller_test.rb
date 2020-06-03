require_relative '../../../test_helper'
require_relative '../../../../core/helpers/account_test_helper'
require_relative '../../../helpers/jwt_test_helper'

module Channel
  module Search
    class TicketsControllerTest < ActionController::TestCase
      include AccountTestHelper
      include JwtTestHelper

      def wrap_cname(params)
        { ticket: params }
      end

      def test_search_ticket
        set_jwt_auth_header(SHERLOCK)
        Channel::Search::TicketsController.any_instance.stubs(:esv2_query_results).returns(::Search::V2::PaginationWrapper.new([]))
        post :results, controller_params(version: 'channel', context: 'spotlight', term: '51', field: 'display_id')
        assert_response 200
        assert_equal '[]', response.body
      end

      def test_search_archive_ticket
        set_jwt_auth_header(SHERLOCK)
        Account.current.add_feature(:archive_tickets)
        Channel::Search::TicketsController.any_instance.stubs(:esv2_query_results).returns(::Search::V2::PaginationWrapper.new([]))
        post :results, controller_params(version: 'channel', context: 'spotlight', term: '51', field: 'display_id')
        assert_response 200
        assert_equal '[]', response.body
      ensure
        Account.current.remove_feature(:archive_tickets)
      end

      def test_search_archive_ticket_without_user
        set_jwt_auth_header(SHERLOCK)
        Account.current.add_feature(:archive_tickets)
        @controller.stubs(:current_user).returns(nil)
        Channel::Search::TicketsController.any_instance.stubs(:esv2_query_results).returns(::Search::V2::PaginationWrapper.new([]))
        post :results, controller_params(version: 'channel', context: 'spotlight', term: '51', field: 'display_id')
        assert_response 200
        assert_equal '[]', response.body
      ensure
        @controller.unstub(:current_user)
        Account.current.remove_feature(:archive_tickets)
      end

      def test_search_ticket_no_jwt
        post :results, controller_params(version: 'channel', context: 'spotlight', term: '51', field: 'display_id')
        assert_response 403
        assert_equal 'access_denied', JSON.parse(response.body)['code']
      end
    end
  end
end

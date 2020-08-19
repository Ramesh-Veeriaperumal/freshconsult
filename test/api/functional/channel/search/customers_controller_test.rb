require_relative '../../../test_helper'
require_relative '../../../helpers/jwt_test_helper'

class Channel::Search::CustomersControllerTest < ActionController::TestCase
  include JwtTestHelper

  def wrap_cname(params)
    { ticket: params }
  end

  def test_search_contacts
    set_jwt_auth_header(MULTIPLEXER)
    Channel::Search::CustomersController.any_instance.stubs(:esv2_query_results).returns(::Search::V2::PaginationWrapper.new([]))
    post :results, controller_params(version: 'channel', context: 'filteredContactSearch', term: 'bob.Tree@freshdesk.com')
    assert_response 200
    assert_equal '[]', response.body
  ensure
    Channel::Search::CustomersController.any_instance.unstub(:esv2_query_results)
  end

  def test_search_contacts_to_respond_403_without_jwt
    post :results, controller_params(version: 'channel', context: 'filteredContactSearch', term: 'bob.Tree@freshdesk.com')
    assert_response 403
    assert_equal 'access_denied', JSON.parse(response.body)['code']
  end
end

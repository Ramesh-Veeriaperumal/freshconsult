require_relative '../../../test_helper'

module Channel::V2
  class TicketFiltersControllerTest < ActionController::TestCase
    include QueryHashHelper
    include TicketFiltersHelper
    include GroupsTestHelper

    def wrap_cname(params)
      { ticket_filter: params }
    end

    def setup
      super
      before_all
    end

    def before_all
      @account = Account.first.make_current
      Account.any_instance.stubs(:auto_refresh_revamp_enabled?).returns(true)
      @agent = get_admin.make_current
    end

    # Tests
    # Actions: index, show, create, update and destroy [Each action with different params]

    def test_list_all_filters
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
    end

    def test_show_single_filter_with_invalid_id
      get :show, construct_params({ version: 'private' }, false).merge(id: 0)
      assert_response 404
      get :show, construct_params({ version: 'private' }, false).merge(id: :testing_id)
      assert_response 404
    end

    def test_show_single_filter
      filter1 = create_filter
      get :show, construct_params({ version: 'private' }, false).merge(id: filter1.id)
      assert_response 200
      match_custom_json(response.body, ticket_filter_show_pattern(filter1))
    end

    def test_show_inaccessible_filter
      group = create_group(@account)
      inaccessible_filter = create_filter(nil, custom_ticket_filter: {
                                            visibility: {
                                              visibility: 2,
                                              group_id: group.id
                                            }
                                          })
      get :show, construct_params({ version: 'private' }, false).merge(id: inaccessible_filter.id)
      assert_response 404
    end

    def test_show_invalid_filter
      group = create_group(@account)
      inaccessible_filter = create_filter(nil, custom_ticket_filter: {
                                            visibility: {
                                              visibility: 2,
                                              group_id: group.id
                                            }
                                          })
      get :show, construct_params({ version: 'private' }, false).merge(id: inaccessible_filter.id + 100)
      assert_response 404
    end

    def test_show_with_default_visible_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end

    def test_show_with_default_hidden_filter
      default_filter_id = TicketsFilter.accessible_filters(TicketFilterConstants::HIDDEN_FILTERS).sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end
  end
end

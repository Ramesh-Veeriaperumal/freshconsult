require_relative '../../test_helper'

module Ember
  class TicketFiltersControllerTest < ActionController::TestCase

    include QueryHashHelper
    include TicketFiltersHelper

    def wrap_cname(params)
      { ticket_filter: params }
    end

    def setup
      super
      before_all
    end

    def before_all
      @account = Account.first.make_current
      User.first.make_current
      # create two filters
      @filter1 = create_filter
      @filter2 = create_filter
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
      get :show, construct_params({ version: 'private' }, false).merge(id: @filter1.id)
      assert_response 200
      match_custom_json(response.body, ticket_filter_show_pattern(@filter1))
    end

    def test_show_with_default_visible_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end

    def test_show_with_default_hidden_filter
      default_filter_id = hidden_filter_names.sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end

    def test_create_with_invalid_params
      filter_params = sample_filter_input_params
      post :create, construct_params({ version: 'private' },  filter_params.except(:query_hash, :name))
      assert_response 400
      match_custom_json(response.body, create_error_pattern([:query_hash, :name]))
    end

    def test_create_with_invalid_values
      filter_params = sample_filter_input_params
      filter_params[:order] = 'invalid_order'
      filter_params[:visibility][:visibility] = Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.max + 1 # invalid visibility
      post :create, construct_params({ version: 'private' },  filter_params)
      assert_response 400
      match_json([bad_request_error_pattern('order', :not_included, list: ApiTicketConstants::ORDER_BY.join(',')),
                  bad_request_error_pattern('visibility_id', :not_included, list: Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.join(','))])
    end

    def test_create_with_valid_params
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.now.to_s}"
      filter_params[:name] = new_name
      post :create, construct_params({ version: 'private' },  filter_params)
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_update_with_invalid_params
      filter_params = sample_filter_input_params
      put :update, construct_params({ version: 'private', id: @filter1.id },  filter_params.except(:query_hash, :name))
      assert_response 400
      match_custom_json(response.body, create_error_pattern([:query_hash, :name]))
    end

    def test_update_with_invalid_values
      filter_params = sample_filter_input_params
      filter_params[:order] = 'invalid_order'
      filter_params[:visibility][:visibility] = Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.max + 1 # invalid visibility
      put :update, construct_params({ version: 'private', id: @filter1.id },  filter_params)
      assert_response 400
      match_json([bad_request_error_pattern('order', :not_included, list: ApiTicketConstants::ORDER_BY.join(',')),
                  bad_request_error_pattern('visibility_id', :not_included, list: Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.join(','))])
    end

    def test_update_default_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      put :update, construct_params({ version: 'private', id: default_filter_id },  sample_filter_input_params)
      assert_response 403
    end

    def test_update_with_valid_params
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.now.to_s}"
      filter_params[:name] = new_name
      put :update, construct_params({ version: 'private', id: @filter1.id },  filter_params)
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_update_with_valid_params_without_visibility
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.now.to_s}"
      filter_params[:name] = new_name
      put :update, construct_params({ version: 'private', id: @filter1.id },  filter_params.except(:visibility))
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_destroy_filter_with_invalid_id
      get :destroy, construct_params({ version: 'private', id: 0 }, false)
      assert_response 404
      get :destroy, construct_params({ version: 'private', id: :testing_id }, false)
      assert_response 404
    end

    def test_destroy_default_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      put :destroy, construct_params({ version: 'private', id: default_filter_id }, false)
      assert_response 403
    end

    def test_destroy_valid_filter
      put :destroy, construct_params({ version: 'private', id: @filter2.id }, false)
      assert_response 204
    end

  end
end

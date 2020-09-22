require_relative '../../test_helper'

module Proactive
  class RulesControllerTest < ActionController::TestCase
    include ::Proactive::ProactiveJwtAuth
    include EmailConfigsHelper
    include GroupHelper

    def setup
      super
      Account.find(Account.current.id).make_current
      Account.current.add_feature(:proactive_outreach)
    end

    def wrap_cname(params)
      { rule: params }
    end

    def rule_create_params_hash
      name = 'sample_name'
      description = 'sample description'
      params_hash = { name: name,
                      description: description }
      params_hash
    end

    def rule_filters_fetch_params_hash
      type = 'shopify'
      event = 'abandoned_cart'
      params_hash = { event: event,
                      integration_details: { type: type } }
      params_hash
    end

    def rule_filters_fetch_params_invalid_hash
      type = 'shopify'
      event = 'abandod_cart'
      params_hash = { event: event,
                      integration_details: { type: type } }
      params_hash
    end

    def test_create_rule_with_valid_params
      params_hash = rule_create_params_hash
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"rule\": {\"id\":1,\"name\":\"sample_name\",\"description\":\"sample description\",\"created_at\":\"2018-06-27T11:07:01.000Z\",\"updated_at\":\"2018-06-27T11:07:01.000Z\"}}", status: 201)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
    end

    def test_create_rule_with_invalid_params
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"description\":\"null\",\"errors\":[{\"field\":\"name\",\"message\":\"can't be blank\",\"code\":\"invalid_value\"}]}", status: 400)
      post :create, construct_params(version: 'private', description: 'abcd')
      assert_response 400
    end

    def test_delete_rule
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: 'null', status: 204)
      delete :destroy, construct_params(version: 'private', id: 39)
      assert_response 204
    end

    def test_delete_rule_not_found
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: 'null', status: 404)
      delete :destroy, construct_params(version: 'private', id: 39)
      assert_response 404
    end

    def test_delete_rule_error
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"description\": \"internal server error\"}", status: 500)
      delete :destroy, construct_params(version: 'private', id: 39)
      assert_response 500
    end

    def test_show_rule
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"rule\": {\"id\":39, \"name\":\"sample_name\",\"description\":\"sample description\",\"created_at\":\"2018-06-27T10:48:55.000Z\",\"updated_at\":\"2018-06-27T10:48:55.000Z\"}}", status: 200)
      get :show, construct_params(version: 'private', id: 39)
      assert_response 200
    end

    def test_show_rule_not_found
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: 'null', status: 404)
      get :show, construct_params(version: 'private', id: 39)
      assert_response 404
    end

    def test_update_rule_with_valid_params
      params_hash = rule_create_params_hash
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"rule\": {\"id\":1,\"name\":\"sample_name\",\"description\":\"sample description\",\"created_at\":\"2018-06-27T11:07:01.000Z\",\"updated_at\":\"2018-06-27T11:07:01.000Z\"}}", status: 200)
      put :update, construct_params({ version: 'private', id: 1 }, params_hash)
      assert_response 200
    end

    def test_update_rule_not_found
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: 'null', status: 404)
      put :update, construct_params(version: 'private', id: 1, description: 'abcd')
      assert_response 404
    end

    def test_retrieve_rules
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_index_action_payload.merge(status: 200))
      get :index, controller_params
      assert_response 200
    end

    def test_retrieve_rules_with_pagination
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_index_action_payload.merge(status: 200))
      get :index, controller_params(per_page: 1)
      assert_response 200
    end

    def test_retrieve_rules_with_next_page
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_index_action_payload.merge(status: 200))
      HttpRequestProxy.any_instance.stubs(:all_headers).returns({'link' => 'test.com'})
      get :index, controller_params
      assert_equal true, @response.api_meta[:next]
      assert_response 200
    ensure
      HttpRequestProxy.any_instance.unstub(:all_headers)
    end

    def test_retrieve_rules_with_no_next_page
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_index_action_payload.merge(status: 200))
      get :index, controller_params
      assert_nil @response.api_meta
      assert_response 200
    end

    def test_retrieve_rules_invalid
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"description\": \"bad request error\"}", status: 400)
      get :index, controller_params
      assert_response 400
    end

    def test_fetch_filters_with_valid_params
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"shopify_fields\" : { \"name\": \"name\", \"type\": \"text\", \"operations\": [\"not_equals\"]} }", status: 200)
      post :filters, construct_params({ version: 'private' }, rule_filters_fetch_params_hash)
      assert_response 200
    end

    def test_fetch_filters_with_invalid_params
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{ \"validation_failed\": { \"errors\": [{\"type\": \"text\"}] } }", status: 400)
      post :filters, construct_params({ version: 'private' }, rule_filters_fetch_params_invalid_hash)
      assert_response 200
    end
    
    def test_create_abandoned_cart_rule_with_email
      email_config = fetch_email_config
      params_hash = rule_create_params_hash.merge(event: 'abandoned_cart',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: email_config.id,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: @account.groups.last.id || create_group(@account).id
                                                    }
                                                  })
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_with_email_action('abandoned_cart').merge(status: 201))
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
    end

    def test_create_delivery_feedback_rule_with_email
      email_config = fetch_email_config
      params_hash = rule_create_params_hash.merge(event: 'delivery_feedback',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: email_config.id,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: @account.groups.last.id || create_group(@account).id
                                                    }
                                                  })
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_with_email_action('delivery_feedback').merge(status: 201))
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
    end

    def test_update_abandoned_cart_rule_with_email
      email_config = fetch_email_config
      params_hash = rule_create_params_hash.merge(event: 'abandoned_cart',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: email_config.id,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: @account.groups.last.id || create_group(@account).id
                                                    }
                                                  })
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_with_email_action('abandoned_cart').merge(status: 200))
      put :update, construct_params({ version: 'private', id: 1 }, params_hash)
      assert_response 200
    end

    def test_update_delivery_feedback_rule_with_email
      email_config = fetch_email_config
      params_hash = rule_create_params_hash.merge(event: 'delivery_feedback',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: email_config.id,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: @account.groups.last.id || create_group(@account).id
                                                    }
                                                  })
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(rules_with_email_action('delivery_feedback').merge(status: 200))
      put :update, construct_params({ version: 'private', id: 1 }, params_hash)
      assert_response 200
    end

    def test_create_with_invalid_email_params
      params_hash = rule_create_params_hash.merge(event: 'abandoned_cart',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: 9999,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: 9999
                                                    }
                                                  })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id),
                  bad_request_error_pattern('group', :"can't be blank", code: :invalid_value)])
    end

    def test_update_with_invalid_email_params
      params_hash = rule_create_params_hash.merge(event: 'delivery_feedback',
                                                  action: {
                                                    email: {
                                                      subject: 'subject',
                                                      description: '<div>description</div>',
                                                      email: 'sample@test.com',
                                                      email_config_id: 9999,
                                                      status: 4,
                                                      type: 'Question',
                                                      priority: 4,
                                                      group_id: 9999
                                                    }
                                                  })
      put :update, construct_params({ version: 'private', id: 1 }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id),
                  bad_request_error_pattern('group', :"can't be blank", code: :invalid_value)])
    end

    def test_preview_email
      params_hash = {"event":"abandoned_cart","integration_details":{"type":"shopify"},"email_body":"<div>kjnefwnnvefknfe</div>", "subject": "<div>Dummy</div>"}
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: '{"placeholders":[{"name":"total_price","label":"Total Price","dummy_value":"50"}]}', status: 200)
      post :preview_email, construct_params({ version: 'private', id: 1 }, params_hash)
      assert_response 200
    end

    def fetch_email_config
      Account.current.email_configs.where('active = true').first || create_email_config
    end

    def rules_with_email_action(event)
      { text: "{\"rule\":{\"id\":4,\"sample_name\":\"name\",\"description\":\"sample description\",\"event\":\"#{event}\",\"action\":{\"email\":{\"subject\":\"subject\",\"description\":\"\\u003cdiv\\u003edescription\\u003c/div\\u003e\",\"email\":\"sample@test.com\",\"email_config_id\":1,\"status\":4,\"type\":\"Question\",\"priority\":4,\"group_id\":1}},\"created_at\":\"2018-09-19T15:47:04.000Z\",\"updated_at\":\"2018-09-20T04:06:35.000Z\"}}" }
    end

    def rules_index_action_payload
      { text: "{\"rules\": [{\"id\":1,\"name\":\"test\",\"description\":\"new\",\"type\":0,\"created_at\":\"2018-08-01T07:24:54.000Z\",\"updated_at\":\"2018-08-01T07:24:54.000Z\"},{\"id\":2,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T07:25:02.000Z\",\"updated_at\":\"2018-08-01T07:25:02.000Z\"},{\"id\":3,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T08:30:00.000Z\",\"updated_at\":\"2018-08-01T08:30:00.000Z\"}]}" }
    end
  end
end

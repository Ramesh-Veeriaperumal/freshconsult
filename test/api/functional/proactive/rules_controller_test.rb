require_relative '../../test_helper'
module Proactive
  class RulesControllerTest < ActionController::TestCase
    include ::Proactive::ProactiveJwtAuth
    def setup
      super
      Account.find(Account.current.id).make_current
      Account.current.add_feature(:proactive_outreach)
    end

    def wrap_cname(params)
      { rules: params }
    end

    def rule_create_params_hash
      name = 'sample_name'
      description = 'sample description'
      params_hash = { name: name,
                      description: description }
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
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"rules\": [{\"id\":1,\"name\":\"test\",\"description\":\"new\",\"type\":0,\"created_at\":\"2018-08-01T07:24:54.000Z\",\"updated_at\":\"2018-08-01T07:24:54.000Z\"},{\"id\":2,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T07:25:02.000Z\",\"updated_at\":\"2018-08-01T07:25:02.000Z\"},{\"id\":3,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T08:30:00.000Z\",\"updated_at\":\"2018-08-01T08:30:00.000Z\"}]}", status: 200)
      get :index, controller_params
      assert_response 200
    end

    def test_retrieve_rules_with_pagination
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"rules\": [{\"id\":1,\"name\":\"test\",\"description\":\"new\",\"type\":0,\"created_at\":\"2018-08-01T07:24:54.000Z\",\"updated_at\":\"2018-08-01T07:24:54.000Z\"},{\"id\":2,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T07:25:02.000Z\",\"updated_at\":\"2018-08-01T07:25:02.000Z\"},{\"id\":3,\"name\":\"test\",\"description\":\"safsdfaasf\",\"type\":0,\"created_at\":\"2018-08-01T08:30:00.000Z\",\"updated_at\":\"2018-08-01T08:30:00.000Z\"}]}", status: 200)
      get :index, controller_params(per_page: 1)
      assert_response 200
    end

    def test_retrieve_rules_invalid
      HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(text: "{\"description\": \"bad request error\"}", status: 400)
      get :index, controller_params
      assert_response 400
    end
  end
end

require_relative '../../../test_helper'

module Ember::Search
  class MultiqueryControllerTest < ActionController::TestCase

    include PrivilegesHelper

    def test_result_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.words, limit: 3, templates: ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']})
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_result_with_valid_params
      templates = ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      response = parse_response @response.body
      assert templates.all? {|d| response.has_key?(d)}
    end

    def test_result_with_invalid_template
      templates = ['agentSpotlightTicket', Faker::Lorem.word]
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      assert_response 400
    end

    def test_result_with_invalid_context
      templates = ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: Faker::Lorem.word, term:  Faker::Lorem.word, limit: 3, templates: templates})
      assert_response 400
    end

    def test_result_as_restricted_agent
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      templates = ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      response = parse_response @response.body
      assert templates.all? {|d| response.has_key?(d)}
    ensure
      user.agent.update_attributes(:ticket_permission => permission)
    end

    def test_result_with_SO_enabled
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])

      Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)

      templates = ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      response = parse_response @response.body
      assert templates.all? {|d| response.has_key?(d)}   
    ensure
      user.agent.update_attributes(:ticket_permission => permission)
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_result_with_special_enabled
      Account.current.launch(:es_v2_splqueries)
      templates = ['agentSpotlightTicket', 'agentSpotlightCustomer', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      response = parse_response @response.body
      assert templates.all? {|d| response.has_key?(d)}   
    ensure
      Account.current.rollback(:es_v2_splqueries)
    end

    # Commented for Hack for forums, to be used when forums feature has been migrated to bitmap
    # def test_result_without_forums_feature
    #   account = Account.current
    #   f = account.features.forums
    #   account.features.forums.destroy
    #   account.reload
    #   templates = ['agentSpotlightTicket', 'agentSpotlightSolution', 'agentSpotlightTopic']
    #   post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
    #   assert_response 400
    # ensure
    #   account.features.forums.create unless f.new_record?
    # end

    def test_result_without_solutions_privilege
      user = User.current
      privilege = user.privilege? :view_solutions
      remove_privilege(user, :view_solutions)
      templates = ['agentSpotlightTicket', 'agentSpotlightSolution', 'agentSpotlightTopic']
      post :search_results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.word, limit: 3, templates: templates})
      assert_response 403
    ensure
      add_privilege(user, :view_solutions) if privilege
    end
  end
end

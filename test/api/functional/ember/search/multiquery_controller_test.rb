require_relative '../../../test_helper'

module Ember::Search
  class MultiqueryControllerTest < ActionController::TestCase
    include PrivilegesHelper

    AGENT_SPOTLIGHT_CUSTOMER = 'agentSpotlightCustomer'.freeze
    AGENT_SPOTLIGHT_TICKET = 'agentSpotlightTicket'.freeze
    AGENT_SPOTLIGHT_SOLUTION = 'agentSpotlightSolution'.freeze
    AGENT_SPOTLIGHT_TOPIC = 'agentSpotlightTopic'.freeze
    MQUERY_TEMPLATES = [AGENT_SPOTLIGHT_TICKET, AGENT_SPOTLIGHT_CUSTOMER, AGENT_SPOTLIGHT_SOLUTION, AGENT_SPOTLIGHT_TOPIC].freeze

    PRIVATE_VERSION = 'private'.freeze
    SPOTLIGHT = 'spotlight'.freeze

    def test_result_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.words, limit: 3, templates: MQUERY_TEMPLATES)
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_result_with_valid_params
      templates = MQUERY_TEMPLATES
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    end

    def test_result_with_invalid_template
      templates = [AGENT_SPOTLIGHT_TICKET, Faker::Lorem.word]
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 400
    end

    def test_result_with_invalid_context
      templates = MQUERY_TEMPLATES
      post :search_results, construct_params(version: PRIVATE_VERSION, context: Faker::Lorem.word, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 400
    end

    def test_result_as_restricted_agent
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      templates = MQUERY_TEMPLATES
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      user.agent.update_attributes(ticket_permission: permission)
    end

    def test_result_with_so_enabled
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])

      Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)

      templates = MQUERY_TEMPLATES
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      user.agent.update_attributes(ticket_permission: permission)
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_result_with_special_enabled
      Account.current.enable_setting(:es_v2_splqueries)
      templates = MQUERY_TEMPLATES
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      Account.current.disable_setting(:es_v2_splqueries)
    end

    # Commented for Hack for forums, to be used when forums feature has been migrated to bitmap
    # def test_result_without_forums_feature
    #   account = Account.current
    #   f = account.features.forums
    #   account.features.forums.destroy
    #   account.reload
    #   templates = [AGENT_SPOTLIGHT_TICKET, AGENT_SPOTLIGHT_SOLUTION, AGENT_SPOTLIGHT_TOPIC]
    #   post :search_results, onstruct_params({version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
    #   assert_response 400
    # ensure
    #   account.features.forums.create unless f.new_record?
    # end

    def test_result_without_solutions_privilege
      user = User.current
      privilege = user.privilege? :view_solutions
      remove_privilege(user, :view_solutions)
      templates = [AGENT_SPOTLIGHT_TICKET, AGENT_SPOTLIGHT_SOLUTION, AGENT_SPOTLIGHT_TOPIC]
      post :search_results, construct_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 403
    ensure
      add_privilege(user, :view_solutions) if privilege
    end

    def test_result_get_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.words, limit: 3, templates: MQUERY_TEMPLATES)
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_result_get_with_valid_params
      templates = MQUERY_TEMPLATES
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    end

    def test_result_get_with_invalid_template
      templates = [AGENT_SPOTLIGHT_TICKET, Faker::Lorem.word]
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 400
    end

    def test_result_get_with_invalid_context
      templates = MQUERY_TEMPLATES
      get :search_results, controller_params(version: PRIVATE_VERSION, context: Faker::Lorem.word, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 400
    end

    def test_result_get_as_restricted_agent
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      templates = MQUERY_TEMPLATES
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      user.agent.update_attributes(ticket_permission: permission)
    end

    def test_result_get_with_so_enabled
      user = User.current
      permission = user.agent.ticket_permission
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])

      Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)

      templates = MQUERY_TEMPLATES
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      user.agent.update_attributes(ticket_permission: permission)
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_result_get_with_special_enabled
      Account.current.enable_setting(:es_v2_splqueries)
      templates = MQUERY_TEMPLATES
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      response = parse_response @response.body
      assert(templates.all? { |d| response.key?(d) })
    ensure
      Account.current.disable_setting(:es_v2_splqueries)
    end

    def test_result_get_without_solutions_privilege
      user = User.current
      privilege = user.privilege? :view_solutions
      remove_privilege(user, :view_solutions)
      templates = [AGENT_SPOTLIGHT_TICKET, AGENT_SPOTLIGHT_SOLUTION, AGENT_SPOTLIGHT_TOPIC]
      get :search_results, controller_params(version: PRIVATE_VERSION, context: SPOTLIGHT, term: Faker::Lorem.word, limit: 3, templates: templates)
      assert_response 403
    ensure
      add_privilege(user, :view_solutions) if privilege
    end
  end
end

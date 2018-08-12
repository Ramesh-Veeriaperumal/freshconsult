require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

class CannedResponseFoldersControllerTest < ActionController::TestCase
  include GroupHelper
  include CannedResponsesHelper
  include CannedResponseFoldersTestHelper
  include HelpdeskAccessMethods
  include AgentHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @agent = @account.agents.first.user
    @agent.active = true
    @agent.save!

    @ca_folder_all = create_cr_folder(name: Faker::Name.name)
    @ca_folder_personal = @account.canned_response_folders.personal_folder.first

    # responses in visible to all folder
    @ca_response1 = create_canned_response(@ca_folder_all.id)
    @ca_response2 = create_canned_response(@ca_folder_all.id)

    # responses in personal folder
    @ca_response3 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    @ca_response4 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])

    # responses based on groups
    # @test_group = create_group(@account)
    @ca_response5 = create_canned_response(@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
  end

  # Only 2 actions : index & show

  # tests for index
  # 1. all folders listing

  # tests for show
  # 1. list responses visible in the folder
  # 2. should list personal responses
  # 3. should not list personal responses of other agents
  # 4. should not list responses visible in particular group to agents not in the group
  # 5. Check with invalid folder id

  def test_index_listing
    remove_wrap_params

    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:ca_folders_es_request).returns(nil)
    get :index, construct_params({ version: 'v2' }, false)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:ca_folders_es_request)

    assert_response 200
    match_json(ca_folders_pattern)
  end

  def test_show_list_responses

    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:es_request).returns(nil)
    get :show, construct_params({ version: 'v2' }, false).merge(id: @ca_folder_all.id)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:es_request)

    assert_response 200

    match_json(ca_responses_pattern(@ca_folder_all))
  end

  def test_show_responses_in_personal_folder_of_self
    login_as(@agent)

    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:es_request).returns(nil)
    get :show, construct_params({ version: 'v2' }, false).merge(id: @ca_folder_personal.id)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:es_request)

    assert_response 200
    match_json(ca_responses_pattern(@ca_folder_personal))

    responses = ActiveSupport::JSON.decode(response.body)['canned_responses']
    assert responses.include?(single_ca_response_pattern(@ca_response3))
    assert responses.include?(single_ca_response_pattern(@ca_response4))
  end

  def test_show_personal_responses_of_other_agents
    new_agent = add_agent_to_account(@account, { name: Faker::Name.name, active: 1, role: 1 })
    login_as(new_agent.user)

    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:es_request).returns(nil)
    get :show, construct_params({ version: 'v2' }, false).merge(id: @ca_folder_personal.id)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:es_request)

    assert_response 200
    match_json(ca_responses_pattern(@ca_folder_personal))
    responses = ActiveSupport::JSON.decode(response.body)['canned_responses']
    refute responses.include?(single_ca_response_pattern(@ca_response3))
    refute responses.include?(single_ca_response_pattern(@ca_response4))
  end

  def test_show_with_group_visibility_response
    new_agent = add_agent_to_account(@account, { name: Faker::Name.name, active: 1, role: 1 })
    login_as(new_agent.user)

    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:es_request).returns(nil)
    get :show, construct_params({ version: 'v2' }, false).merge(id: @ca_folder_all.id)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:es_request)

    assert_response 200
    match_json(ca_responses_pattern(@ca_folder_all))
    responses = ActiveSupport::JSON.decode(response.body)['canned_responses']
    assert responses.include?(single_ca_response_pattern(@ca_response1))
    assert responses.include?(single_ca_response_pattern(@ca_response2))
    refute responses.include?(single_ca_response_pattern(@ca_response5))
  end

  def test_show_invalid_folder_id
    get :show, construct_params({ version: 'v2' }, false).merge(id: 0)
    assert_response 404
  end

end

require_relative '../test_helper'
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

    @ca_folder_all = create_cr_folder(name: SecureRandom.uuid)
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

  def canned_response_attributes
    {
      response: {
        title: Faker::Name.name,
        folder_id: 1,
        helpdesk_accessible_attributes:
        {
          accessible_type: 'Admin::CannedResponses::Response',
          access_type: 0
        },
        content_html: 'Test'
      }
    }
  end

  def test_index_listing
    remove_wrap_params
    
    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:ca_folders_es_request).returns(nil)
    get :index, construct_params({ version: 'v2' }, false)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:ca_folders_es_request)

    assert_response 200
    match_json(ca_folders_pattern)
  end

  def test_index_for_cr_with_multiple_groups
    new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    login_as(new_agent.user)
    # create groups
    groups = create_groups(Account.current, options = { count: 20 })
    group_ids = groups.map(&:id)

    # assign group to agent
    groups.each do |group|
      Account.current.agent_groups.create(user_id: new_agent.user.id, group_id: group.id)
    end

    folder1 = create_cr_folder(name: 'Test folder 1')
    folder2 = create_cr_folder(name: 'Test folder 2')

    # assign group to cr
    params = {
      response: {
        title: 'Test',
        folder_id: folder1.id,
        helpdesk_accessible_attributes:
        {
          accessible_type: 'Admin::CannedResponses::Response',
          access_type: 2,
          group_ids: group_ids
        },
        content_html: 'Test'
      }
    }

    crs = []
    25.times do |i|
      params[:response][:title] = "Test CR folder1 #{i}"
      params[:response][:folder_id] = folder1.id
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
      params[:response][:title] = "Test CR folder2 #{i}"
      params[:response][:folder_id] = folder2.id
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end
    get :index, controller_params(version: 'v2')
    assert_response 200
    response_body = JSON.parse(response.body)

    assert response_body.map { |res| res['id'] }.include?(folder1.id), 'Folder 1 not present in response'
    assert response_body.map { |res| res['id'] }.include?(folder2.id), 'Folder 2 not present in response'

    assert_equal folder1.canned_responses.count, response_body.detect { |res| res['id'] == folder1.id }['responses_count']
    assert_equal folder2.canned_responses.count, response_body.detect { |res| res['id'] == folder2.id }['responses_count']
  ensure
    new_agent.destroy
    crs.map(&:destroy)
    groups.map(&:destroy)
    folder1.destroy
    folder2.destroy
  end

  def test_index_for_crs_higher_than_limit
    new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    login_as(new_agent.user)
    # create groups
    groups = create_groups(Account.current, options = { count: 20 })
    group_ids = groups.map(&:id)

    # assign group to agent
    groups.each do |group|
      Account.current.agent_groups.create(user_id: new_agent.user.id, group_id: group.id)
    end
    folders = []

    20.times do |i|
      folders << create_cr_folder(name: "Test folder #{i}")
    end

    # assign group to cr
    params = {
      response: {
        title: 'Test',
        folder_id: 1,
        helpdesk_accessible_attributes:
        {
          accessible_type: 'Admin::CannedResponses::Response',
          access_type: 2,
          group_ids: group_ids
        },
        content_html: 'Test'
      }
    }

    crs = []
    20.times do |i|
      20.times do |j|
        params[:response][:title] = "Test CR folder #{j} #{i}"
        params[:response][:folder_id] = folders[j].id
        crs << canned_response = Account.current.canned_responses.new(params[:response])
        canned_response.save!
      end
    end
    get :index, controller_params(version: 'v2')
    assert_response 200
    response_body = JSON.parse(response.body)

    folders_diff = folders.map(&:id) - response_body.map { |res| res['id'] }
    assert !folders_diff.count.zero?, 'All folders present in response'
  ensure
    new_agent.destroy
    crs.map(&:destroy)
    groups.map(&:destroy)
    folders.map(&:destroy)
  end

  def test_index_with_split_and_combine
    global_folder = Account.current.canned_response_folders.new(name: 'global folder')
    global_folder.save
    group_folder = Account.current.canned_response_folders.new(name: 'Group folder')
    group_folder.save

    first_agent = @agent
    login_as(@agent)
    second_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)

    params = canned_response_attributes

    crs = []
    20.times do |i|
      params[:response][:title] = "global cr #{i}"
      params[:response][:folder_id] = global_folder.id
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end

    # Group access type
    agent_groups = create_groups(Account.current, options = { count: 2 })
    non_agent_groups = create_groups(Account.current, options = { count: 2 })

    # assign group to agent
    agent_groups.each do |group|
      Account.current.agent_groups.create(user_id: first_agent.id, group_id: group.id)
    end
    params[:response][:helpdesk_accessible_attributes][:access_type] = 2
    params[:response][:helpdesk_accessible_attributes][:group_ids] = agent_groups.map(&:id)

    10.times do |i|
      params[:response][:title] = "agent group cr #{i}"
      params[:response][:folder_id] = group_folder.id
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end

    params[:response][:helpdesk_accessible_attributes][:group_ids] = non_agent_groups.map(&:id)

    10.times do |i|
      params[:response][:title] = "non agent group cr #{i}"
      params[:response][:folder_id] = group_folder.id
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end

    # User access

    params[:response][:helpdesk_accessible_attributes][:access_type] = 1

    # User 1
    params[:response][:title] = "user access cr #{first_agent.id}"
    params[:response][:folder_id] = group_folder.id
    crs << canned_response = Account.current.canned_responses.new(params[:response])
    canned_response.save!
    user_access1 = Helpdesk::UserAccess.new(user_id: User.current.id, access_id: canned_response.helpdesk_accessible.id)
    user_access1.save!

    # User 2
    params[:response][:title] = "user access cr #{second_agent.user_id}"
    params[:response][:folder_id] = group_folder.id
    crs << canned_response = Account.current.canned_responses.new(params[:response])
    canned_response.save!
    user_access2 = Helpdesk::UserAccess.new(user_id: second_agent.user_id, access_id: canned_response.helpdesk_accessible.id)
    user_access2.save!

    get :index, controller_params(version: 'v2')
    assert_response 200

    folders = accessible_elements(Account.current.canned_responses, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, :folder)).map(&:folder)
    folders.uniq.sort_by { |f| [f.folder_type, f.name] }.map { |f| f.visible_responses_count = folders.count(f) }

    expected_folders = folders.uniq.map(&:id).sort
    response_folders = JSON.parse(response.body).map { |x| x['id'] }.sort

    assert_equal expected_folders, response_folders, 'Folders mismatch!'

    expected_count = {}
    response_count = {}

    folders.uniq.map { |x| expected_count[x.id] = x.visible_responses_count }
    JSON.parse(response.body).map { |x| response_count[x['id']] = x['responses_count'] }

    assert_equal expected_count, response_count, 'Folder count mismatch!'
  ensure
    crs.map(&:destroy)
    global_folder.destroy
    group_folder.destroy
    second_agent.destroy
    agent_groups.map(&:destroy)
    non_agent_groups.map(&:destroy)
  end

  def test_index_with_cr_limit_increase
    folder = create_cr_folder(name: 'Test folder')
    params = {
      response: {
        title: 'Test',
        folder_id: folder.id,
        helpdesk_accessible_attributes:
        {
          accessible_type: 'Admin::CannedResponses::Response',
          access_type: 0
        },
        content_html: 'Test'
      }
    }
    crs = []
    (1..350).each do |i|
      params[:response][:title] = "Test CR #{i}"
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end
    settings = Account.current.account_additional_settings
    settings.additional_settings[:canned_responses_limit] = 400
    settings.save
    get :index, controller_params(version: 'v2')
    folder_count = JSON.parse(response.body).select { |f| f['id'] == folder.id }.last['responses_count']
    assert_equal 350, folder_count
  ensure
    crs.map(&:destroy)
    folder.destroy
    settings.additional_settings.delete(:canned_responses_limit)
    settings.save
  end

  def test_index_with_access_type_limit
    Account.current.canned_responses.destroy_all
    folder = create_cr_folder(name: 'Test folder')
    params = {
      response: {
        title: 'Test',
        folder_id: folder.id,
        helpdesk_accessible_attributes:
        {
          accessible_type: 'Admin::CannedResponses::Response',
          access_type: 0
        },
        content_html: 'Test'
      }
    }
    crs = []
    (1..30).each do |i|
      params[:response][:title] = "Test CR #{i}"
      crs << canned_response = Account.current.canned_responses.new(params[:response])
      canned_response.save!
    end
    settings = Account.current.account_additional_settings
    settings.additional_settings[:canned_responses_all_limit] = 10
    settings.save

    get :index, controller_params(version: 'v2')
    folder_count = JSON.parse(response.body).select { |f| f['id'] == folder.id }.last['responses_count']
    assert folder_count < 30, 'Folder count matching!'
  ensure
    crs.map(&:destroy)
    folder.destroy
    settings.additional_settings.delete(:canned_responses_all_limit)
    settings.save
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
    @agent.stubs(:privilege?).with(:manage_tickets).returns(true)
    ::Search::V2::Count::AccessibleMethods.any_instance.stubs(:es_request).returns(nil)

    get :show, construct_params({ version: 'v2' }, false).merge(id: @ca_folder_personal.id)
    ::Search::V2::Count::AccessibleMethods.any_instance.unstub(:es_request)
    @agent.unstub(:privilege?)

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

  def test_create
    name = SecureRandom.uuid
    folder = {
      name: name
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 201
    match_json(ca_folder_create_pattern(name, ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_duplicate
    folder = {
      name: @ca_folder_all.name
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 409
  end

  def test_create_privilage_check
    User.any_instance.stubs(:privilege?).with(:manage_canned_responses).returns(false)
    folder = {
      name: SecureRandom.uuid
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_create_with_invalid_datatype
    folder = {
      name: 1
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 400
  end

  def test_create_with_personal
    folder = {
      name: 'Personal_'
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 400
  end

  def test_create_with_length
    folder = {
      name: 'as'
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 400
  end

  def test_create_with_invalid_params1
    folder = {
      name: 'test',
      test: 2
    }
    post :create, construct_params(build_request_param(folder))
    assert_response 400
  end

  def test_create_with_invalid_params2
    post :create, construct_params({ version: 'v2', canned_response_folder: {}})
    assert_response 400
  end

  def test_update
    folder = {
      name: SecureRandom.uuid
    }
    ca_folder = create_cr_folder(name: SecureRandom.uuid)
    put :update, construct_params(build_request_param(folder)).merge(id: ca_folder.id)
    assert_response 200
    ca_folder.reload
    match_json(ca_create_pattern(ca_folder))
  end

  def test_update_privilage_check
    User.any_instance.stubs(:privilege?).with(:manage_canned_responses).returns(false)
    folder = {
      name: SecureRandom.uuid
    }
    put :update, construct_params(build_request_param(folder)).merge(id: @ca_folder_all.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_update_with_invalid_datatype
    folder = {
      name: 1
    }
    put :update, construct_params(build_request_param(folder)).merge(id: @ca_folder_all.id)
    assert_response 400
  end

  def test_update_with_personal
    folder = {
      name: 'Personal_'
    }
    put :update, construct_params(build_request_param(folder)).merge(id: @ca_folder_all.id)
    assert_response 400
  end

  def test_update_with_length
    folder = {
      name: 'as'
    }
    put :update, construct_params(build_request_param(folder)).merge(id: @ca_folder_all.id)
    assert_response 400
  end

  def test_update_with_invalid_params1
    folder = {
      name: 'test',
      test: 2
    }
    put :update, construct_params(build_request_param(folder)).merge(id: @ca_folder_all.id)
    assert_response 400
  end

  def test_update_with_invalid_params2
    put :update, construct_params({ version: 'v2', canned_response_folder: {} }).merge(id: @ca_folder_all.id)
    assert_response 400
  end

  def test_update_personal_folder
    put :update, construct_params({ version: 'v2', canned_response_folder: {name: 'test'} }).merge(id: @ca_folder_personal.id)
    assert_response 400
  end

  def test_create_cr_folder_in_auditlog
    CentralPublisher::Worker.jobs.clear
    folder = {
      name: SecureRandom.uuid
    }
    post :create, construct_params(build_request_param(folder))
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'canned_response_folder_create', job['args'].first
    CentralPublisher::Worker.jobs.clear
  end

  def test_update_cr_folder_changes_in_auditlog
    begin
      CentralPublisher::Worker.jobs.clear
      old_name = SecureRandom.uuid
      new_name = SecureRandom.uuid
      folder = {
        name: new_name
      }
      ca_folder = create_cr_folder(name: old_name)
      put :update, construct_params(build_request_param(folder)).merge(id: ca_folder.id)
      assert_response 200
      job = CentralPublisher::Worker.jobs.last
      assert_equal 'canned_response_folder_update', job['args'].first
      assert_equal({ 'name' => [old_name, new_name] }, job['args'].second['model_changes'])
    rescue => e
      p "Central publisher job :: #{job.inspect}"
      assert_equal 'canned_response_folder_update', job['args'].first
    ensure
      CentralPublisher::Worker.jobs.clear
    end
  end

  def test_delete_cr_folder_in_auditlog
    begin
      CentralPublisher::Worker.jobs.clear
      ca_folder = create_cr_folder(name: SecureRandom.uuid)
      ca_folder.destroy
      job = CentralPublisher::Worker.jobs.last
      assert_equal 'canned_response_folder_destroy', job['args'].first
    rescue => e
      p "Central publisher job :: #{job.inspect}"
      assert_equal 'canned_response_folder_destroy', job['args'].first
    ensure
      CentralPublisher::Worker.jobs.clear
    end
  end

  def test_create_a_cr_folder_with_existing_name
    ca_folder = create_cr_folder(name: 'refund_folder')
    ca_folder.save
    another_ca_folder = {
      name: 'refund_folder'
    }
    post :create, construct_params(build_request_param(another_ca_folder))
    assert_response 409
    match_json([bad_request_error_pattern('name', :'has already been taken')])
  ensure
    ca_folder.destroy
  end

  def test_create_a_cr_folder_with_deleted_folder_name
    name = SecureRandom.uuid
    ca_folder = create_cr_folder(name: name)
    ca_folder.deleted = true
    ca_folder.save
    post :create, construct_params(build_request_param(name: name))
    assert_response 201
    match_json(ca_folder_create_pattern(name, ActiveSupport::JSON.decode(response.body)['id']))
  ensure
    ca_folder.destroy
  end
end

require_relative '../test_helper'
require_relative '../../core/helpers/users_test_helper'
class ApiRolesControllerTest < ActionController::TestCase
  include CoreUsersTestHelper
  include RolesTestHelper
  include QmsTestHelper
  def wrap_cname(params)
    { api_role: params }
  end

  def test_index
    CustomRequestStore.store[:private_api_request] = false
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << role_pattern(role)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_index_with_collaboration_roles_enabled
    CustomRequestStore.store[:private_api_request] = false
    Account.any_instance.stubs(:launched?).returns(true)
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << role_pattern(role)
    end
    assert_response 200
    match_json(pattern.ordered!)
  ensure
    Account.any_instance.unstub(:launched?)
  end

  def test_show_role
    role = Role.first
    get :show, construct_params(id: role.id)
    assert_response 200
    match_json(role_pattern(role))
  end

  def test_show_with_collaboration_roles_enabled
    role = Role.first
    Account.any_instance.stubs(:launched?).returns(true)
    get :show, construct_params(id: role.id)
    assert_response 200
    match_json(role_pattern(role))
  ensure
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_show_request_for_missing_role
    get :show, construct_params(id: 2000)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_role_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_index_without_privilege
    role = Role.first
    User.any_instance.stubs(:privilege?).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    get :show, construct_params(id: role.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_index_with_link_header
    3.times do
      create_role(name: Faker::Name.name, privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts',
                                                           'view_reports', '', '0', '0', '0', '0'])
    end
    per_page =  Account.current.roles_from_cache.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/roles?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_create_custom_role_with_contact_privilege_without_feature
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_contacts', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'new role1', privilege_list: privileges)
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal true, test_agent.privilege?(:manage_companies)
    assert_equal test_agent.privilege?(:manage_contacts), test_agent.privilege?(:manage_companies)
  end

  def test_create_custom_role_with_contact_privilege_with_feature
    Account.current.launch(:contact_company_split)
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_contacts', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'new role2', privilege_list: privileges)
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:manage_companies)
    assert_not_equal test_agent.privilege?(:manage_contacts), test_agent.privilege?(:manage_companies)
  ensure
    Account.current.rollback :contact_company_split
  end

  def test_create_custom_role_without_contact_privilege_with_feature
    Account.current.launch(:contact_company_split)
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'view_reports', '', '0', '0', '0', '0']
    test_role = create_role(name: 'new role3', privilege_list: privileges)
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:manage_companies)
    assert_equal test_agent.privilege?(:manage_contacts), test_agent.privilege?(:manage_companies)
  ensure
    Account.current.rollback :contact_company_split
  end

  def test_create_custom_role_without_contact_privilege_without_feature
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'view_reports', '', '0', '0', '0', '0']
    test_role = create_role(name: 'new role4', privilege_list: privileges)
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:manage_companies)
    assert_equal test_agent.privilege?(:manage_contacts), test_agent.privilege?(:manage_companies)
  end

  def test_create_custom_role_without_contact_privilege_with_company_privilege_without_feature
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_companies', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'new role5', privilege_list: privileges)
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:manage_companies)
    assert_equal test_agent.privilege?(:manage_contacts), test_agent.privilege?(:manage_companies)
  end

  def test_create_custom_role_with_contact_delete_privilege_without_feature
    test_role = create_role(name: 'new role6', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts','delete_contact',
                                                           'view_reports', '', '0', '0', '0', '0'])
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal true, test_agent.privilege?(:delete_company)
    assert_equal test_agent.privilege?(:delete_contact), test_agent.privilege?(:delete_company)
  end

  def test_create_custom_role_with_contact_delete_privilege_with_feature
    Account.current.launch(:contact_company_split)
    test_role = create_role(name: 'new role7', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts','delete_contact',
                                                           'view_reports', '', '0', '0', '0', '0'])
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:delete_company)
    assert_not_equal test_agent.privilege?(:delete_contact), test_agent.privilege?(:delete_company)
  ensure
    Account.current.rollback :contact_company_split
  end

  def test_create_custom_role_without_contact_delete_privilege_with_feature
    Account.current.launch(:contact_company_split)
    test_role = create_role(name: 'new role8', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts',
                                                           'view_reports', '', '0', '0', '0', '0'])
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:delete_company)
    assert_equal test_agent.privilege?(:delete_contact), test_agent.privilege?(:delete_company)
  ensure
    Account.current.rollback :contact_company_split
  end

  def test_create_custom_role_without_contact_delete_privilege_without_feature
    test_role = create_role(name: 'new role9', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts',
                                                           'view_reports', '', '0', '0', '0', '0'])
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:delete_company)
    assert_equal test_agent.privilege?(:delete_contact), test_agent.privilege?(:delete_company)
  end

  def test_create_custom_role_without_contact_delete_privilege_with_company_delete_privilege_without_feature
    test_role = create_role(name: 'new role10', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_company',
                                                           'view_reports', '', '0', '0', '0', '0'])
    test_agent = add_agent(Account.current, role_ids: test_role.id)
    assert_equal false, test_agent.privilege?(:delete_company)
    assert_equal test_agent.privilege?(:delete_contact), test_agent.privilege?(:delete_company)
  end

  def test_index_with_qms_enabled
    enable_qms
    CustomRequestStore.store[:private_api_request] = false
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << role_pattern(role)
    end
    assert_response 200
    assert Account.current.roles.map(&:name).include?('Coach')
    match_json(pattern.ordered!)
  ensure
    disable_qms
  end

  def test_index_with_qms_disabled
    disable_qms
    CustomRequestStore.store[:private_api_request] = false
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << role_pattern(role)
    end
    assert_response 200
    assert !Account.current.roles.map(&:name).include?('Coach')
    match_json(pattern.ordered!)
  end
end

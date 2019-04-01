require_relative '../../test_helper'

class RolesControllerTest < ActionController::TestCase
  tests ApiRolesController
  include RolesTestHelper

  def wrap_cname(params)
    { api_role: params }
  end

  def test_show_without_privilege
    role = Role.first
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :show, construct_params(id: role.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_index_without_privilege
    role = Role.first
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :index, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_bulk_update_without_privilege
    role = Role.first
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :bulk_update, controller_params({ids: [role.id]})
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_index
    CustomRequestStore.store[:private_api_request] = true
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << private_role_pattern(role)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_bulk_update_with_no_params
    post :bulk_update, construct_params({ version: 'private' }, {})
    match_json([bad_request_error_pattern('ids', :missing_field),
      bad_request_error_pattern('options', :missing_field)])
    assert_response 400
  end

  def test_bulk_update_default_role_validation_failure
    create_role(name: 'test contacts', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts',
                                                           'view_reports', '', '0', '0', '0', '0'])
    role = Role.first
    contact_role = Role.find_by_name('test contacts')

    post :bulk_update, construct_params({ version: 'private' },
      ids: [role.id, contact_role.id], options: { privileges: { add: ['manage_contacts']}})
    failures = {}
    failures[role.id] = { id: :default_role_modified }
    assert_response 202
    match_json(partial_success_response_pattern([contact_role.id], failures))
  end

  def test_bulk_update_default_agent_role_validation
    CustomRequestStore.store[:private_api_request] = true
    role = Role.find_by_name('Agent')
    admin_role = Role.first
    post :bulk_update, construct_params({ version: 'private' },
      ids: [role.id, admin_role.id], options: { privileges: { add: ['manage_availability', 'view_admin']}})
    failures = {}
    failures[role.id] = { id: :default_role_modified }
    assert_response 202
    match_json(partial_success_response_pattern([admin_role.id], failures))
  end

  def test_bulk_update_success
    CustomRequestStore.store[:private_api_request] = true
    role = Role.first
    post :bulk_update, construct_params({ version: 'private' },
      ids: [role.id], options: { privileges: { add: ['manage_availability', 'view_admin']}})
    assert_response 204
  end

  def test_bulk_update_role_validation_failure
    create_role(name: 'test view contact', privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                                                           'view_reports', '', '0', '0', '0', '0'])
    role = Role.find_by_name('test view contact')

    post :bulk_update, construct_params({ version: 'private' },
      ids: [role.id], options: { privileges: { add: ['manage_contacts']}})
    failures = {}
    failures[role.id] = { privilege_list: [:missing_privileges, list: 'view_contacts'] }
    assert_response 202
    match_json(partial_success_response_pattern([], failures))
  end

  def test_bulk_update_role_validation_failure_skill
    create_role(name: 'test edit skill', privilege_list: ['manage_tickets', 'view_contacts', 'view_forums',
                                                           'view_reports', '', '0', '0', '0', '0'])
    role = Role.find_by_name('test edit skill')

    post :bulk_update, construct_params({ version: 'private' },
      ids: [role.id], options: { privileges: { add: ['edit_ticket_skill']}})
    failures = {}
    failures[role.id] = { privilege_list: [:missing_privileges, list: 'edit_ticket_properties'] }
    assert_response 202
    match_json(partial_success_response_pattern([], failures))
  end
end
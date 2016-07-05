require_relative '../test_helper'
class ApiRolesControllerTest < ActionController::TestCase
  include RolesTestHelper
  def wrap_cname(params)
    { api_role: params }
  end

  def test_index
    get :index, controller_params
    pattern = []
    Account.current.roles_from_cache.each do |role|
      pattern << role_pattern(role)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_role
    role = Role.first
    get :show, construct_params(id: role.id)
    assert_response 200
    match_json(role_pattern(role))
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
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false).once
    get :show, construct_params(id: role.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
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
end

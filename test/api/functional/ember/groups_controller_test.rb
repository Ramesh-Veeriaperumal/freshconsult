require_relative '../../test_helper'
class Ember::GroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper

  def wrap_cname(params)
    { group: params }
  end

  def test_group_index
    3.times do
      create_group(@account)
    end
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.groups.order(:name).all.each do |group|
      pattern << group_pattern_without_assingn_type(group)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_group
    group = create_group(@account)
    get :show, controller_params(version: 'private', id: group.id)
    assert_response 200
    match_json(group_pattern_without_assingn_type(Group.find(group.id)))
  end

  def test_show_group_without_manage_availability_privilege
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    group = create_group(@account)
    get :show, controller_params(version: 'private', id: group.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

end

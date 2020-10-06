require_relative '../../../test_helper'
class Channel::Freshconnect::GroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper

  def setup
    super
    @account.reload
  end

  def test_groups_index
    old_count = @account.groups.size
    groups = []
    31.times { groups << create_group_with_agents(@account) }
    set_jwt_auth_header('freshconnect')
    get :index, controller_params(version: 'channel')
    assert_response 200
    actual_groups = parse_response @response.body
    assert_equal 31 + old_count, actual_groups.size
    expected_group_ids = @account.groups.map(&:id).sort
    actual_group_ids = actual_groups.map { |group| group['id'] }.sort
    assert_equal expected_group_ids, actual_group_ids
    actual_groups_sample = actual_groups.first.with_indifferent_access
    sample_group = @account.groups.find(actual_groups_sample['id'])
    expected_group_response = GroupDecorator.new(sample_group, {}).to_index_hash.with_indifferent_access
    assert_equal(expected_group_response.keys.map(&:to_sym), actual_groups_sample.keys.map(&:to_sym))
    expected_group_response.each_key do |group_dec_attr|
      assert_equal(expected_group_response[group_dec_attr], actual_groups_sample[group_dec_attr])
    end
  ensure
    groups.each(&:destroy)
  end
end

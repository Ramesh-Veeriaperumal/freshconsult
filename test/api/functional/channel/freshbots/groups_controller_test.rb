require_relative '../../../test_helper'
class Channel::Freshbots::GroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper

  def setup
    super
  end

  def test_groups_index
    5.times { create_group_with_agents(@account) }
    set_jwt_auth_header('freshbots')
    get :index, controller_params(version: 'channel')
    assert_response 200
    actual_groups = parse_response @response.body
    expected_group_ids = @account.groups.map(&:id).sort
    actual_group_ids = actual_groups.map { |group| group['id'] }.sort
    assert_equal expected_group_ids, actual_group_ids
    actual_groups_sample = actual_groups.first.with_indifferent_access
    sample_group = @account.groups.find(actual_groups_sample['id'])
    expected_group_response = GroupDecorator.new(sample_group, {}).freshbots_index_hash.with_indifferent_access
    assert_equal(expected_group_response.keys.map(&:to_sym).to_set, actual_groups_sample.keys.map(&:to_sym).to_set)
    expected_group_response.keys.each do |group_dec_attr|
      assert_equal(expected_group_response[group_dec_attr], actual_groups_sample[group_dec_attr])
    end
  end
end

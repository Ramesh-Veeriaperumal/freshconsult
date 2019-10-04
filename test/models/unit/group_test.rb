require_relative '../test_helper'

class GroupTest < ActiveSupport::TestCase
  include ModelsGroupsTestHelper

  def test_group_assignment_type_update_on_lbrr_v2_feature_addition
    @account.revoke_feature(:lbrr_by_omniroute)
    non_lbrr_groups = [
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:default]),
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:round_robin]),
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment])
    ]
    lbrr_group = create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:round_robin], capping_limit: 5)
    @account.add_feature(:lbrr_by_omniroute)
    non_lbrr_groups.each do |group|
      old_assignment_type = group.ticket_assign_type
      group.reload
      assert_equal old_assignment_type, group.ticket_assign_type
    end
    lbrr_group.reload
    assert_equal Group::TICKET_ASSIGN_TYPE[:lbrr_by_omniroute], lbrr_group.ticket_assign_type
  ensure
    @account.revoke_feature(:lbrr_by_omniroute)
  end

  def test_group_assignment_type_update_on_lbrr_v2_feature_removal
    @account.add_feature(:lbrr_by_omniroute)
    non_lbrr_groups = [
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:default]),
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:round_robin]),
      create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment])
    ]
    lbrr_group = create_group(@account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:lbrr_by_omniroute])
    @account.revoke_feature(:lbrr_by_omniroute)
    non_lbrr_groups.each do |group|
      old_assignment_type = group.ticket_assign_type
      group.reload
      assert_equal old_assignment_type, group.ticket_assign_type
    end
    lbrr_group.reload
    assert_equal Group::TICKET_ASSIGN_TYPE[:default], lbrr_group.ticket_assign_type
  ensure
    @account.revoke_feature(:lbrr_by_omniroute)
  end
end

require_relative '../unit_test_helper'
require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class GroupTypeTest < ActionView::TestCase
  include AccountHelper
  include GroupConstants

  DEFAULT_GROUP_TYPE_LIST = {
    support_agent_group: [:support_agent_group, 'support_agent_group', 1],
    field_agent_group: [:field_agent_group, 'field_agent_group', 2]
  }.freeze

  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def get_default_group_details(group_type)
    group_type_details = DEFAULT_GROUP_TYPE_LIST[group_type.to_sym]
    {
      name: group_type_details[0],
      label: group_type_details[1],
      group_type_id: group_type_details[2]
    }
  end

  def test_group_type_id_with_default_support_group_name
    group_type_id = GroupType.group_type_id(SUPPORT_GROUP_NAME)
    assert_equal group_type_id, 1
  end

  def test_group_type_id_with_default_field_group_name
    group_type_id = GroupType.group_type_id(FIELD_GROUP_NAME)
    assert_equal group_type_id, 2
  end

  def test_group_type_name_with_default_support_group_id
    group_type_name = GroupType.group_type_name(1)
    assert_equal group_type_name, SUPPORT_GROUP_NAME
  end

  def test_group_type_name_with_default_field_group_id
    group_type_name = GroupType.group_type_name(2)
    assert_equal group_type_name, FIELD_GROUP_NAME
  end

  def test_group_type_name_with_invlaid_id
    group_type_name = GroupType.group_type_name(-1)
    assert_equal group_type_name, nil
  end

  def test_create_group_type_with_default_field_group_type
    GroupType.where(id: 2).first.try(:destroy)
    group_type = GroupType.create_group_type(@account, FIELD_GROUP_NAME)

    field_group_details = get_default_group_details(FIELD_GROUP_NAME)
    assert_equal group_type.group_type_id, field_group_details[:group_type_id]
    assert_equal group_type.name, field_group_details[:name]
    assert_equal group_type.label, field_group_details[:label]
  end

  def test_create_group_type_with_non_default_group_type
    error = assert_raises(RuntimeError) { GroupType.create_group_type(@account, 'test') }
    assert_equal error.message, 'Invalid group type test'
  end

  def test_create_duplicate_group_type
    GroupType.populate_default_group_types(@account)
    old_count = GroupType.count
    GroupType.populate_default_group_types(@account)
    assert_equal old_count, GroupType.count
  end
end

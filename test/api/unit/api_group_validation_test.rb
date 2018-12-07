require_relative '../unit_test_helper'

class ApiGroupValidationTest < ActionView::TestCase
  def test_value_valid
    group = ApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, auto_ticket_assign: false,
                                     agent_ids: [1, 2], group_type: GroupConstants::SUPPORT_GROUP_NAME }, nil)
    assert group.valid?
  end

  def test_value_invalid_group_type
    Account.stubs(:current).returns(Account.first)
    group = ApiGroupValidation.new({ unassigned_for: '30hh', escalate_to: '23',
                                     description: 123, auto_ticket_assign: 'false',
                                     agent_ids: 123, group_type: 23 }, nil)
    refute group.valid?(:create)
    errors = group.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
    assert errors.include?('Unassigned for not_included')
    assert errors.include?('Escalate to datatype_mismatch')
    assert errors.include?('Agent ids datatype_mismatch')
    assert errors.include?('Description datatype_mismatch')
    assert errors.include?('Auto ticket assign datatype_mismatch')
    assert errors.include?('Group type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_value_invalid
    group = ApiGroupValidation.new({ unassigned_for: '30hh', escalate_to: '23',
                                     description: 123, auto_ticket_assign: 'false',
                                     agent_ids: 123}, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
    assert errors.include?('Unassigned for not_included')
    assert errors.include?('Escalate to datatype_mismatch')
    assert errors.include?('Agent ids datatype_mismatch')
    assert errors.include?('Description datatype_mismatch')
    assert errors.include?('Auto ticket assign datatype_mismatch')
  end

  def test_value_invalid
    group = ApiGroupValidation.new({ unassigned_for: '30hh', escalate_to: '23',
                                     description: 123, auto_ticket_assign: 'false',
                                     agent_ids: 123}, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
    assert errors.include?('Unassigned for not_included')
    assert errors.include?('Escalate to datatype_mismatch')
    assert errors.include?('Agent ids datatype_mismatch')
    assert errors.include?('Description datatype_mismatch')
    assert errors.include?('Auto ticket assign datatype_mismatch')
  end

  def test_array_nil
    group = ApiGroupValidation.new({ name: Faker::Name.name, agent_ids: nil }, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Agent ids datatype_mismatch')
  end
end
require_relative '../unit_test_helper'

class ApiGroupValidationTest < ActionView::TestCase
  def test_value_valid
    group = ApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, auto_ticket_assign: false,
                                     agent_ids: [1, 2] }, nil)
    assert group.valid?
  end

  def test_value_invalid
    group = ApiGroupValidation.new({ unassigned_for: '30hh', escalate_to: '23',
                                     description: 123, auto_ticket_assign: 'false',
                                     agent_ids: 123 }, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Name data_type_mismatch')
    assert errors.include?('Unassigned for not_included')
    assert errors.include?('Escalate to data_type_mismatch')
    assert errors.include?('Agent ids data_type_mismatch')
    assert errors.include?('Description data_type_mismatch')
    assert errors.include?('Auto ticket assign data_type_mismatch')
    assert_equal({ name: { data_type: String, code: :missing_field }, escalate_to: { data_type: :"Positive Integer" },
                   unassigned_for: { list: '30m,1h,2h,4h,8h,12h,1d,2d,3d' }, auto_ticket_assign: { data_type: 'Boolean' },
                   agent_ids: { data_type: Array }, description: { data_type: String } }, group.error_options)
  end

  def test_array_nil
    group = ApiGroupValidation.new({ name: Faker::Name.name, agent_ids: nil }, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Agent ids data_type_mismatch')
  end
end

require_relative '../unit_test_helper'

class PrivateApiGroupValidationTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current) 
  end

  def test_noassignment_valid
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, assignment_type: 0,
                                     agent_ids: [1, 2], group_type: GroupConstants::SUPPORT_GROUP_NAME }, nil)
    assert group.valid?(:create)
  end

  def test_normal_round_robin_valid
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, assignment_type: 1, round_robin_type: 1,
                                     allow_agents_to_change_availability:true, agent_ids: [1, 2] }, nil)
    assert group.valid?    
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
  end

  def test_load_based_round_robin_valid
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, assignment_type: 1, round_robin_type: 2,
                                     allow_agents_to_change_availability:true, capping_limit:10, agent_ids: [1, 2] }, nil)
    assert group.valid?
    Account.any_instance.unstub(:round_robin_capping_enabled?)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
  end  

  def test_skill_based_round_robin_valid
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, assignment_type: 1, round_robin_type: 3,
                                     allow_agents_to_change_availability:true, capping_limit:10, agent_ids: [1, 2] }, nil)
    assert group.valid?
    Account.any_instance.unstub(:round_robin_capping_enabled?)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(false)
  end

  def test_ocr_valid
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, unassigned_for: '30m', escalate_to: 1,
                                     description: Faker::Lorem.paragraph, assignment_type: 2,
                                     allow_agents_to_change_availability:true, agent_ids: [1, 2] }, nil)
    assert group.valid?    
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
  end  

  def test_value_invalid
    group = PrivateApiGroupValidation.new({ unassigned_for: '30hh', escalate_to: '23',
                                     description: 123, auto_ticket_assign: 'false',
                                     agent_ids: 123, group_type: Faker::Lorem.characters(10) }, nil)
    refute group.valid?(:create)
    errors = group.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
    assert errors.include?('Unassigned for not_included')
    assert errors.include?('Escalate to datatype_mismatch')
    assert errors.include?('Agent ids datatype_mismatch')
    assert errors.include?('Description datatype_mismatch')
    assert errors.include?('Auto ticket assign datatype_mismatch')
    assert errors.include?('Group type not_included')
  end

  def test_array_nil
    group = PrivateApiGroupValidation.new({ name: Faker::Name.name, agent_ids: nil }, nil)
    refute group.valid?
    errors = group.errors.full_messages
    assert errors.include?('Agent ids datatype_mismatch')
  end
end

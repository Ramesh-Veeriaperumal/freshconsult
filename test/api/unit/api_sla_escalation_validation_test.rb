require_relative '../unit_test_helper'

class ApiSlaEscalationValidationTest < ActionView::TestCase
  def test_value_valid
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0, agent_ids: [ -1 ] }, nil)
    assert sla.valid?
  end

  def test_escalation_time_nil
    sla = ApiSlaEscalationValidation.new( { escalation_time: nil, agent_ids: [-1] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation time blank')
  end

  def test_escalation_time_invalid_data_type
    sla = ApiSlaEscalationValidation.new( { escalation_time: "Test", agent_ids: [-1] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation time datatype_mismatch')
    assert_equal({ escalation_time: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, agent_ids:{} }, sla.error_options)
  end

  def test_without_escalation_time
    sla = ApiSlaEscalationValidation.new( { agent_ids: [-1] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation time missing_field')
    assert_equal({ escalation_time: { code: :missing_field }, agent_ids: {} }, sla.error_options)
  end

  # ******************************************************************************** Agent Ids

  def test_agent_ids_nil
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0, agent_ids: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Agent ids blank')
  end

  def test_agent_ids_invalid_data_type
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0, agent_ids: {} }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Agent ids blank')
  end

  def test_agent_ids_array_has_invalid_data_type
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0, agent_ids: [ "hbjn" ] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Agent ids array_datatype_mismatch')
  end

  def test_agent_ids_array_empty
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0, agent_ids: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Agent ids blank')
  end

  def test_without_agent_ids
    sla = ApiSlaEscalationValidation.new( { escalation_time: 0 }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Agent ids missing_field')
  end

end
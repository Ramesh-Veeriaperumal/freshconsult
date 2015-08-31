module Helpers::SlaPoliciesHelper
  # Patterns
  def sla_policy_pattern(expected_output = {}, sla_policy)
    conditions_hash = {}
    sla_policy.conditions.each { |key, value| conditions_hash[key.to_s.pluralize] = value } unless sla_policy.conditions.nil?
    {
      id: Fixnum,
      name: sla_policy.name,
      description: sla_policy.description,
      is_default: sla_policy.is_default,
      applicable_to: expected_output[:applicable_to] || conditions_hash,
      position: sla_policy.position,
      active: sla_policy.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def v2_sla_policy_payload
    sla_policy_params.to_json
  end

  def v1_sla_policy_payload
    { helpdesk_sla_policy: v1_sla_policy_params }.to_json
  end

  # private
  def sla_policy_params
    { applicable_to: { company_ids: [1, 2] } }
  end

  def v1_sla_policy_params
    { conditions: { company_id: '1,2' } }
  end
end

include Helpers::SlaPoliciesHelper

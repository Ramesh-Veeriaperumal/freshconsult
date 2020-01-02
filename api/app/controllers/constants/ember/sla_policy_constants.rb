module Ember::SlaPolicyConstants
  include ::SlaPolicyConstants
  ALLOWED_SLA_TARGET_FIELDS = [
    { 'first_response_time' => [nil] }, 'first_response_time',
    { 'every_response_time' => [nil] }, 'every_response_time',
    { 'resolution_due_time' => [nil] }, 'resolution_due_time',
    { 'business_hours' => [nil] }, 'business_hours',
    { 'escalation_enabled' => [nil] }, 'escalation_enabled'
  ].freeze

  ALLOWED_SLA_TARGET_PRIORITY_FIELDS = [
    { 'priority_1' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_1',
    { 'priority_2' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_2',
    { 'priority_3' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_3',
    { 'priority_4' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_4'
  ].freeze

  DEFAULT_POLICY_UNEDITABLE_FIELDS = %w[active position] | ['applicable_to'] |
                                    ['applicable_to' => ALLOWED_CONDITION_FIELDS]

  UPDATE_FIELDS = %w(name description active).freeze |
                  ['sla_target'] | ['sla_target' => ALLOWED_SLA_TARGET_PRIORITY_FIELDS] |
                  ['applicable_to'] | ['applicable_to' => ALLOWED_CONDITION_FIELDS] |
                  ['escalation'] | ['escalation' => ALLOWED_ESCALATION_FIELDS]

  CREATE_FIELDS = UPDATE_FIELDS
end

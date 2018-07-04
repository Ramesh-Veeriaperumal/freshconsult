module AuditLogConstants
  LOAD_OBJECT_EXCEPT = [:filter, :event_name].freeze
  AUTOMATION_RULE_METHODS = {
      'supervisor' => :all_supervisor_rules,
      'dispatcher' => :all_va_rules,
      'observer' => :observer_rules_from_cache
  }.freeze
  AUTOMATION_RULE_TYPES = [
      VAConfig::SUPERVISOR_RULE,
      VAConfig::BUSINESS_RULE,
      VAConfig::OBSERVER_RULE
  ]
  EVENT_TYPES = (AUTOMATION_RULE_METHODS.keys + ['agent', 'subscription']).freeze
  AUDIT_LOG_PARAMS = [:before, :since].freeze
  FEATURE_NAME = [:audit_logs_central_publish].freeze

  BILLING_CYCLE = {
      1 => 'subscription_plan.billing_cycle.monthly',
      3 => 'subscription_plan.billing_cycle.quarterly',
      6 => 'subscription_plan.billing_cycle.sixmonth',
      12 => 'subscription_plan.billing_cycle.annual'
  }.freeze

  MODEL_TRANSLATION_PATH = {
      subscription: 'admin.audit_log.subscription.',
      agent: 'admin.audit_log.agent.',
      action: 'admin.audit_log.action.',
      event_type: 'admin.audit_log.event_type.',
      automation_rule: 'admin.audit_log.automation_rule.'
  }.freeze

  AGENT_TICKET_SCOPE = {
      1 => 'admin.audit_log.agent.global',
      2 => 'admin.audit_log.agent.group',
      3 => 'admin.audit_log.agent.individual'
  }.freeze

  AGENT_AVAILABILITY = {
      0 => 'admin.audit_log.agent.is_available',
      1 => 'admin.audit_log.agent.not_available'
  }.freeze

  AUTOMATION_RULE_TOGGLE = {
      0 => 'admin.audit_log.automation_rule.rule_off',
      1 => 'admin.audit_log.automation_rule.rule_on'
  }.freeze

  FILTER_PARAMS = [:agent, :time, :type, :observer_id, :dispatcher_id, 
                   :agent_id, :supervisor_id, :next].freeze
end.freeze

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

  MODEL_TRANSLATION_PATH = {
      subscription: 'admin.audit_log.subscription.',
      agent: 'admin.audit_log.agent.',
      action: 'admin.audit_log.action.',
      event_type: 'admin.audit_log.event_type.',
      automation_rule: 'admin.audit_log.automation_rule.'
  }.freeze

  TOGGLE_ACTIONS = {
      true => I18n.t('admin.audit_log.toggle_on'),
      false => I18n.t('admin.audit_log.toggle_off')
  }.freeze

  FILTER_PARAMS = [:agent, :time, :type, :observer_id, :dispatcher_id, 
                   :agent_id, :supervisor_id, :next].freeze
end.freeze

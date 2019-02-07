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

  EXPORT_FILTER_PARAMS = [:agent, :action, :type, :performed_by].freeze

  EXPORT_AUDIT_LOG_PARAMS = [:filter].freeze

  ENTITY_HASH = {
    'automation_1' => 1,
    'automation_3' => 3,
    'automation_4' => 4
  }.freeze

  AUTOMATION_TYPES = ['automation_1', 'automation_3', 'automation_4'].freeze

  TYPES = ['agent', 'subscription'].freeze
  
  ACTION_VALUES = ['create', 'delete', 'update'].freeze
  
  EXPORT_ENRICHED_KEYS = [:performer_id, :performer_name, :ip_address, :time, :action].freeze

  WAITING_STATUSES = ['1001', '1002'].freeze

  FAILURE_STATUSES = ['2001', '4000'].freeze

  CSV_FILE = Rails.root.join('tmp', 'files')

  TEMP_FILE = '%{time}_account_%{id}'.freeze

  COLUMN_HEADER = ['Performer_id', 'Performer_name', 'Ip_address', 'Time', 'What Changed', 'Event', 'Description'].freeze
end.freeze

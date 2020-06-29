module AuditLogConstants
  AUTOMATION_RULE_METHODS = {
      'supervisor' => :all_supervisor_rules,
      'dispatcher' => :all_va_rules,
      'observer' => :observer_rules_from_cache,
      'canned_response_folder' => :canned_response_folders,
      'canned_response' => :canned_responses,
      'company' => :companies,
      'solution_categories' => :solution_categories,
      'solution_folders' => :solution_folders,
      'solution_articles' => :solution_articles
  }.freeze
  AUTOMATION_RULE_TYPES = [
      VAConfig::SUPERVISOR_RULE,
      VAConfig::BUSINESS_RULE,
      VAConfig::OBSERVER_RULE
  ]

  EVENT_TYPES = (AUTOMATION_RULE_METHODS.keys + ['agent', 'subscription', 'canned_response', 'canned_response_folder']).freeze
  AUDIT_LOG_PARAMS = [:before, :since].freeze
  FEATURE_NAME = [:audit_logs_central_publish].freeze

  EXPORT_TYPE_CONST = {
    cannedResponse: 'Canned Response',
    cannedResponseFolder: 'canned Response Folder',
    category: 'Knowledge Base - Category',
    folder: 'Knowledge Base - Folder',
    article: 'Knowledge Base - Article'
  }.freeze

  AUTOMATION_EXPORT_TYPE = {
    supervisor:  'Automation - Time triggers',
    dispatcher:  'Automation - Ticket creation',
    observer:  'Automation - Ticket updates'
  }.freeze

  EVENT_TYPES_NAME = {
    'canned_response' => :title,
    'article' => :title
  }.freeze

  MODEL_TRANSLATION_PATH = {
      subscription: 'admin.audit_log.subscription.',
      agent: 'admin.audit_log.agent.',
      company: 'admin.audit_log.company.',
      action: 'admin.audit_log.action.',
      event_type: 'admin.audit_log.event_type.',
      automation_rule: 'admin.audit_log.automation_rule.',
      canned_response_folder: 'admin.audit_log.canned_response_folder.',
      canned_response: 'admin.audit_log.canned_response.',
      folder: 'admin.audit_log.solution_folder.',
      article: 'admin.audit_log.solution_article.'
  }.freeze

  TOGGLE_ACTIONS = {
      true => I18n.t('admin.audit_log.toggle_on'),
      false => I18n.t('admin.audit_log.toggle_off')
  }.freeze

  FILTER_PARAMS = [:agent, :time, :type, :observer_id, :dispatcher_id,
                   :agent_id, :supervisor_id, :next, :company_id, :canned_response_id, :canned_response_folder_id,
                   :solution_categories_id, :solution_folders_id, :solution_articles_id].freeze

  EXPORT_FILTER_PARAMS = [:action, :performed_by].freeze

  ENTITY_HASH = {
    'automation_1' => 1,
    'automation_3' => 3,
    'automation_4' => 4
  }.freeze

  EXPORT_PARAMS = [:from, :to, :filter, :condition, :receive_via, :export_format, :archived].freeze

  EXPORT_FILTER_SET_PARAMS = [:entity, :ids].freeze

  AUTOMATION_TYPES = ['automation_1', 'automation_3', 'automation_4'].freeze

  TYPES = ['agent', 'subscription', 'company', 'canned_response', 'canned_response_folder', 'solution_categories', 'solution_folders', 'solution_articles'].freeze

  SOLUTIONS_EVENT_ITEMS = %w[category folder article].freeze

  RESET_RATING_FIELDS = %i[thumbs_up thumbs_down article_thumbs_up article_thumbs_down].freeze

  ACTION_VALUES = ['create', 'delete', 'update'].freeze

  EXPORT_ENRICHED_KEYS = [:performer_id, :performer_name, :ip_address, :time, :action].freeze

  WAITING_STATUSES = ['1001', '1002'].freeze

  FAILURE_STATUSES = ['2001', '4000'].freeze

  EXPORT_FILE_PATH = Rails.root.join('tmp', 'files')

  TEMP_FILE = '%{time}_account_%{id}'.freeze

  COLUMN_HEADER = ['Performer_id', 'Performer_name', 'Ip_address', 'Time', 'What Changed', 'Event', 'Description'].freeze

  LOAD_OBJECT_EXCEPT = [:export_s3_url, :filter, :event_name, :export].freeze

  EXPORT_TYPE = 'audit_log'.freeze

  CONDITION_UPPER_CASE = ['AND', 'OR'].freeze

  CONDITION_LOWER_CASE = ['and', 'or'].freeze

  RECEIVE_VIA = ['email', 'api'].freeze

  ERB_PATH = Rails.root.join('app/views/support/audit_log_export/%<file_name>s.xls.erb').to_path

  FORMAT = ['csv', 'xls'].freeze

  ARCHIVED = [true, false].freeze

  VISIBILITY_ID_BY_NAMES = { all_users: 1, logged_in_users: 2, agents: 3, companies: 4, bot: 5, contact_segments: 6, company_segments: 7 }.freeze
  VISIBILITY_NAMES_BY_ID = VISIBILITY_ID_BY_NAMES.invert

  ORDERING_ID_BY_NAMES = { manual: 1, alphabetical: 2, created_desc: 3, created_asc: 4, updated_desc: 5 }.freeze
  ORDERING_NAMES_BY_ID = ORDERING_ID_BY_NAMES.invert
end.freeze

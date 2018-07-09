module Sync::Templatization::Constant
  IGNORE_ASSOCIATIONS_LIST = ['flexifield_def_entry', 'ticket_field_def', 'features'].freeze

  INDEX_VALUE_BY_ACTION_TYPE = {
    modified: 1,
    added: 1,
    deleted: 0,
    conflict: 2
  }.freeze

  GLOBAL_IGNORE_COLUMNS = ['created_at', 'updated_at'].freeze
  INGNORE_COLUMNS_BY_MODEL = {
    'Helpdesk::Attachment' => ['content_updated_at']
  }.freeze
end

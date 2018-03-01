module TodoConstants
  CREATE_FIELDS = %w(body type rememberable_id reminder_at).freeze | ApiConstants::DEFAULT_PARAMS
  UPDATE_FIELDS = %w(body completed reminder_at).freeze | ApiConstants::DEFAULT_PARAMS
  INDEX_FIELDS  = %w(rememberable_id type).freeze |
                    ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  SHOW_FIELDS = ApiConstants::DEFAULT_PARAMS
  TODO_PARAMS_MAPPINGS = { completed: :deleted }.freeze
  VALIDATION_CLASS = 'TodoValidation'.freeze
  SINGULAR_RESPONSE_FOR = %w(create update).freeze
  REMEMBERABLES = [
    [:ticket,   'find_ticket',  'reminders',        'ticket_id'],
    [:contact,  'find_user',    'contact_reminders','contact_id'],
    [:company,  'find_company', 'reminders',        'company_id']
  ].freeze
  FIND_REMEMBERABLE = Hash[*REMEMBERABLES.map { |i| [i[0], i[1]] }.flatten]
  REMINDERS = Hash[*REMEMBERABLES.map { |i| [i[0], i[2]] }.flatten]
  # order of ticket_id, contact_id, company_id must be preseved in 
  # REMEMBERABLE_FIELD_MAP to find correct rememberable type.
  REMEMBERABLE_FIELD_MAP = REMEMBERABLES.map { |i| [i[0], i[3]] }
  MAX_LENGTH_OF_TODO_CONTENT = 250
  TODO_REMEMBERABLES = ['ticket', 'contact', 'company'].freeze
  TYPE_TO_RESOURCE_MAP = Hash.new(:"ember/todo").merge({
      contact: :'ember/contact/todo',
      company: :'ember/contact/todo'
    })
  PRELOAD_RESOURCES_MAP = Hash.new([:ticket, :contact, :company]).merge({
      contact: [:company],
      company: [:contact],
      ticket: []
    })
  MESSAGE_TYPE = "todo_message_type"
  SCHEDULER_TYPE = "todo_scheduler_type"
  IRIS_TYPE = "todo_reminder"
end.freeze

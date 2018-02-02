module IntegratedResourceConstants
  INDEX_FIELDS  = %w(installed_application_id local_integratable_id local_integratable_type).freeze
  CREATE_FIELDS = %w(application_id local_integratable_id local_integratable_type remote_integratable_id remote_integratable_type installed_application_id).freeze
  VALIDATION_CLASS = 'IntegratedResourceValidation'.freeze
  INTEGRATABLE_TYPES = %w(Helpdesk::TimeSheet Helpdesk::Ticket).freeze
  TICKET = 'Helpdesk::Ticket'.freeze
  TIMESHEET = 'Helpdesk::TimeSheet'.freeze
  INTEGRATIONS_USING_DISPLAY_ID = [Integrations::Application::APP_NAMES[:google_calendar]].freeze
end.freeze

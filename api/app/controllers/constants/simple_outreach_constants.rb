module SimpleOutreachConstants
  IMPORT_TYPE = 'contact'.freeze
  IMPORT_STARTED = { import_status: Admin::DataImport::IMPORT_STATUS[:started] }.freeze
  SELECTION_IMPORT = 'import'.freeze
  SELECTION_SEGMENT = 'segment'.freeze
  SELECTION_CONTACT = 'contacts'.freeze
  SELECTION_TYPES = [SELECTION_IMPORT, SELECTION_SEGMENT, SELECTION_CONTACT].freeze

  COMPOSE_EMAIL_FIELDS = %w[subject description email email_config_id cc_emails].freeze
  VALIDATION_CLASSES = %w[Proactive::EmailValidation Proactive::SimpleOutreachValidation Proactive::CustomerImportValidation].freeze
  DELEGATOR_CLASSES = %w[Proactive::SimpleOutreachDelegator].freeze
  SIMPLE_OUTREACH_FIELDS = %w[name description selection].freeze
  SELECTION_FIELDS = %w[type contact_import].freeze
  CONTACT_IMPORT_FIELDS = %w[attachment_id attachment_file_name fields].freeze
end

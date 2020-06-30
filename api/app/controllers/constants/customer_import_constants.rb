module CustomerImportConstants
  CREATE_FIELDS = %w(fields file).freeze

  # validation class
  VALIDATION_CLASS = 'CustomerImportValidation'.freeze
  INDEX_FIELDS = ['status'].freeze
  ALLOWED_STATUS_PARAMS = Admin::DataImport::IMPORT_STATUS.keys.map(&:to_s) - ['started', 'file_created'].freeze + ['in_progress'].freeze

  CONTACT_IMPORT_WRAP_PARAMS = [:api_contact_import, exclude: [], format: [:json, :multipart_form]].freeze
  COMPANY_IMPORT_WRAP_PARAMS = [:api_company_import, exclude: [], format: [:json, :multipart_form]].freeze

  INVALID_CSV_FILE_ERROR = { file: :invalid_csv_file }.freeze
  IMPORT_STARTED = { import_status: Admin::DataImport::IMPORT_STATUS[:started] }.freeze
  IMPORT_WORKERS = {
    'company' => Import::CompanyWorker,
    'contact' => Import::ContactWorker
  }.freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form]
  }.freeze
  NO_CONTENT_TYPE_REQUIRED = [:cancel].freeze
  ACCEPTED_FILE_TYPE = { accepted: 'CSV' }.freeze
  CSV_FILE_EXTENSION_REGEX = /.*\.csv\z/i.freeze
  INVALID_FILE_TAGS = %w[php].freeze
end

module CustomerImportConstants
  CREATE_FIELDS = %w(fields file).freeze

  # validation class
  VALIDATION_CLASS = 'CustomerImportValidation'.freeze

  WRAP_PARAMS = [:customer_import, exclude: [], format: [:json, :multipart_form]].freeze
  LOAD_OBJECT_EXCEPT = [:status]

  INVALID_CSV_FILE_ERROR = { file: :invalid_csv_file }.freeze
  IMPORT_STARTED = { import_status: Admin::DataImport::IMPORT_STATUS[:started] }.freeze
  IMPORT_WORKERS = {
    'company' => Import::CompanyWorker,
    'contact' => Import::ContactWorker
  }.freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form]
  }.freeze
  ACCEPTED_FILE_TYPE = { accepted: 'CSV' }.freeze
  CSV_FILE_EXTENSION_REGEX = /.*\.csv\z/
end

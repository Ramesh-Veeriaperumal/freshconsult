module CustomerImportConstants

  CREATE_FIELDS = %w(type fields file).freeze
  
  # validation class
  VALIDATION_CLASS = 'CustomerImportValidation'.freeze

  CUSTOMER_IMPORT_TYPES = %w(contact company).freeze
  TYPE = "type"
  VALID_INDEX_PARAMS = %w(type).freeze
  WRAP_PARAMS = [:customer_import, exclude: [], format: [:json, :multipart_form]].freeze

  INVALID_CSV_FILE_ERROR = { file: :invalid_csv_file }
  IMPORT_STARTED = { import_status: Admin::DataImport::IMPORT_STATUS[:started] }
  IMPORT_WORKERS = {
    "company" => Import::CompanyWorker,
    "contact" => Import::ContactWorker
  }
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form]
  }
  ACCEPTED_FILE_TYPE = { accepted: "CSV" }
  CSV_CONTENT_TYPE = "text/csv"
end
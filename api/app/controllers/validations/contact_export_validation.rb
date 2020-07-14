class ContactExportValidation < ExportCsvValidation
  def default_field_names
    Account.current.safe_send("#{@export_type}_form").safe_send("default_#{@export_type}_fields", true).map(&:name)
  end
end

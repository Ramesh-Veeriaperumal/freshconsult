class DataExportDelegator < BaseDelegator
  
  validate :validate_export_status, on: :account_export
  
  def initialize(record, options = {})
    super(record, options)
    @data_export = record
  end
  
  def validate_export_status
    errors[:data_export] << I18n.t("export_data_running") if 
      @data_export && !@data_export.completed? && !@data_export.failed?
  end
  
end
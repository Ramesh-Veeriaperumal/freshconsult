class AuditLogDelegator < BaseDelegator
  attr_accessor :rule_id, :agent_id

  validate :validate_export_limit

  def initialize(request_params)
    @export_params = request_params.deep_symbolize_keys
    super(request_params)
  end

  def validate_export_limit
    if DataExport.audit_log_export_limit_reached?
      errors[:processing] << :'your request is in process'
    end
  end
end

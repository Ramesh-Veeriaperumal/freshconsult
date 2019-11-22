class HyperTrail::AuditLog < HyperTrail::Base
  def hyper_trail_type
    'audit_log'
  end

  def hyper_trail_filtered_export
    'audit_log_filtered_export'
  end

  def hyper_trail_archived_export
    'audit_log_archived_export'
  end

  def hyper_trail_file_export
    'audit_log_file_export'
  end
end

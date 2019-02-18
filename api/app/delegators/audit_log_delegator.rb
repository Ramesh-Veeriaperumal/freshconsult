class AuditLogDelegator < BaseDelegator
  attr_accessor :rule_id, :agent_id

  validate :validate_export_limit

  validate :validate_rule_id, if: -> { @export_params[:filter] &&
                                     ( @export_params[:filters][:observer_id].present? ||
                                       @export_params[:filters][:dispatcher_id].present? ||
                                       @export_params[:filters][:supervisor_id].present? )}
  validate :validate_agent_id, if: -> { @export_params[:filter] &&
                                      ( @export_params[:filters][:agent_id].present? ||
                                        @export_params[:filters][:performed_by].present? )}

  def initialize(request_params)
    @export_params = request_params.deep_symbolize_keys
    super(request_params)
  end
  
  def validate_export_limit
    if DataExport.audit_log_export_limit_reached?
      return errors[:processing] << :please_wait_value_is_in_process
    end
  end

  def validate_rule_id
    if @export_params[:filters][:observer_id].present? && !count_rule_id(@export_params[:filters][:observer_id])
      return errors[:rule_id] << :invalid_rule_id
    end
    if @export_params[:filters][:dispatcher_id].present? && !count_rule_id(@export_params[:filters][:dispatcher_id])
       return errors[:rule_id] << :invalid_rule_id
    end
    if @export_params[:filters][:supervisor_id].present? && !count_rule_id(@export_params[:filters][:supervisor_id])
       return errors[:rule_id] << :invalid_rule_id
    end
  end

  def validate_agent_id
    if @export_params[:filters][:agent_id].present? && !count_agent_id(@export_params[:filters][:agent_id])
      return errors[:agent_id] << :invalid_agent_id
    end
    if @export_params[:filters][:performed_by].present? && !count_agent_id(@export_params[:filters][:performed_by]) 
      return errors[:agent_id] << :invalid_agent_id
    end
  end

  private

    def current_account
      current_account ||= Account.current
    end

    def count_rule_id(rule_ids)
      result = current_account.account_va_rules.where("id in (#{rule_ids.join(',')})")
      result.count == rule_ids.count
    end

    def count_agent_id(agent_ids)
      result = current_account.technicians.where("id in (#{agent_ids.join(',')})")
      result.count == agent_ids.count
    end
end

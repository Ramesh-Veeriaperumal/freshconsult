class AuditLogValidation < ApiValidation
  attr_accessor :type, :agent, :time, :name

  validate :validate_feature_check?
  validate :validate_automation_rules?, if: -> { type.present? }
  validate :validate_time?, if: -> { time.present? }
  validate :validate_agent?, if: -> { agent.present? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def validate_automation_rules?
    unless AuditLogConstants::EVENT_TYPES.include? type
      errors[:type] << :invalid_rule_type
    end
  end

  def validate_feature_check?
    unless Account.current.audit_logs_central_publish_enabled?
      errors[:condition] << :require_feature
      error_options.merge!(condition: { feature: AuditLogConstants::FEATURE_NAME[0],
                                        code: :access_denied })
    end
  end

  def validate_time?
    time = @request_params[:time]
    before = time[:from]
    since = time[:to]
    time = local_time(Time.now)
    return errors[:'from/to'] << :invalid_time_period unless before.present? && since.present?
    return errors[:'from<to'] << :invalid_time_range if before > since
    before_time = format_time(before)
    since_time = format_time(since)
    Rails.logger.info "Current time => #{time}, before time => #{before_time}, since time => #{since_time}"
    errors[:'from/to'] << :start_time_lt_now if before_time > time || since_time > time
  end

  def validate_agent?
    if agent.present? && !agent.is_a?(Integer)
      errors[:agent] << :invalid_agent_id
    end
  end

  private
    def format_time(time)
      local_time(Time.at(time / 1000))
    end

    def local_time(time)
      time.getlocal('+00:00').to_i * 1000
    end
end

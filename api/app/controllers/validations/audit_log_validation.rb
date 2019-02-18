class AuditLogValidation < ApiValidation
  attr_accessor :type, :agent, :time, :name

  validate :validate_feature_check?
  validate :validate_automation_rules?, if: -> { type.present? && @request_params[:action] == 'filter'}
  validate :validate_time?, if: -> { time.present? && @request_params[:action] == 'filter' }
  validate :validate_agent?, if: -> { agent.present? && @request_params[:action] == 'filter' }
  validate :validate_from_to?, if: -> { @request_params[:action] == 'export' }
  validate :validate_filter_set?, if: -> { @request_params[:filter] && @request_params[:action] == 'export'}

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

  def validate_export_automation_rules(value)
    if !(AuditLogConstants::TYPES.include? value[0]) && !(AuditLogConstants::AUTOMATION_TYPES.include? value[0])
      errors[:type] << :invalid_rule_type
    end
 end

  def validate_filter_set?
    if @request_params[:filter]
      AuditLogConstants::EXPORT_FILTER_PARAMS.each do |query_param|
        value = @request_params[:filter][query_param]
        next if value.blank?
        
        check_action_values(value) if query_param == :action
        return errors[:filter_value] << :values_not_in_array unless value.is_a?(Array)
      end
    end
    filter_set_validation
  end

  def filter_set_validation
    (1..6).each do |itr|
      filter_sets = "filter_set_#{itr}".to_sym
      filter_set = @request_params[:filter][filter_sets]
      next if filter_set.blank?

      rule_id = filter_set[:ids]
      rule_name = filter_set[:entity]
      validate_export_automation_rules(filter_set[:entity])
      return errors[:filter_value] << :invalid_filter_value_or_empty unless rule_name.present? && rule_name.count == 1
      return errors[:filter_value] << :values_not_in_array unless rule_name.is_a?(Array)
      if rule_id
        return errors[:filter_value] << :values_not_in_array unless rule_id.is_a?(Array)
      end
    end
  end

  def validate_from_to?
    return errors[:'from/to'] << :invalid_time_period unless @request_params[:to].present? && @request_params[:from].present?
    before = Date.parse @request_params[:to]
    since = Date.parse @request_params[:from]
    months = (before.year * 12 + before.month) - (since.year * 12 + since.month)
    years = before.year - since.year
    return errors[:'from/to'] << :conditions_and_filters_are_only_for_between_six_months if months > 6 && @request_params[:condition]
    return errors[:'from/to'] << :time_limit_exceeded if years > 2
    return errors[:'from<to'] << :invalid_time_range if since > before
  end

  private

    def format_time(time)
      local_time(Time.at(time / 1000))
    end

    def local_time(time)
      time.getlocal('+00:00').to_i * 1000
    end

    def check_action_values(value)
      value.each do |val|
        return errors[:action] << :'value must be create/delete/update' unless AuditLogConstants::ACTION_VALUES.include? val
      end
    end
end

class AuditLogValidation < ApiValidation
  attr_accessor :type, :agent, :time, :name

  validate :validate_feature_check?
  validate :validate_automation_rules?, if: -> { type.present? && @request_params[:action] == 'filter' }
  validate :validate_time?, if: -> { time.present? && @request_params[:action] == 'filter' }
  validate :validate_agent?, if: -> { agent.present? && @request_params[:action] == 'filter' }
  validate :validate_from_to?, if: -> { @request_params[:action] == 'export' }
  validate :validate_receive_via, if: -> { @request_params[:action] == 'export' }
  validate :validate_filter_set?, if: -> { @request_params[:filter] && @request_params[:action] == 'export' }
  validate :validate_condition, if: -> { (@request_params[:condition] || (@request_params[:filter] && @request_params[:filter].count > 1)) && @request_params[:action] == 'export' }

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

  def validate_export_automation_rules(entity)
    entity.each do |val|
      if !(AuditLogConstants::TYPES.include? val) && !(AuditLogConstants::AUTOMATION_TYPES.include? val)
        errors[:entity] << :"valid entity is #{ AuditLogConstants::TYPES.join(',') }, #{ AuditLogConstants::AUTOMATION_TYPES.join(',') }"
      end
    end
  end

  def validate_filter_set?
    if @request_params[:filter]
      AuditLogConstants::EXPORT_FILTER_PARAMS.each do |query_param|
        value = @request_params[:filter][query_param]
        next unless @request_params[:filter].key?(query_param)

        return errors[:filter_value] << :values_not_in_array unless value.is_a?(Array)

        return errors[:filter_value] << "#{query_param} should not be empty" if value.empty?

        if query_param == :action
          check_action_values(value)
        elsif query_param == :performed_by
          value.each { |val| errors[:filter_value] << :"#{val} must be in integer" unless val.is_a?(Integer) }
        end
      end
    end
    filter_set_validation
  end

  def filter_set_validation
    type_count = 0
    filter_count = 0
    @request_params[:filter].each do |filter_sets|
      return errors[:filters] << :'Maximum number of filters allowed is four' unless filter_count <= 4
      filter_count += 1
      filter_sets.each do |filter_set|
        if filter_set.is_a?(String)
          return errors[:'filter values'] << :"#{filter_set} is a invalid filter value" unless AuditLogConstants::EXPORT_FILTER_PARAMS.to_s.include?(filter_set) ||
                                                                                               filter_set.include?('filter_set')
        end
        filter_sets_key = filter_set.to_sym if filter_set.include? 'filter_set'
        filter_set_value = @request_params[:filter][filter_sets_key]
        next if filter_set_value.blank?

        entity_ids = filter_set_value[:ids]
        entity_name = filter_set_value[:entity]
        if entity_ids.nil?
          type_count += 1
          return errors[:entity] << :'entity without ids should be given in single filter set' if type_count > 1
        end
        return errors[:entity] << :'ids should have interger value' if filter_set_value.key?(:ids) && entity_ids.blank?

        return errors[:filter_value] << :'entity not in array' unless entity_name.is_a?(Array)

        if entity_ids
          return errors[:filter_value] << :'ids not in array' unless entity_ids.is_a?(Array)
          return errors[:entity] << :'entity should have one value' if entity_name.count > 1
        end
        entity_ids.each { |ruleid| errors[:ids] << :'ids value must be in Integer' unless ruleid.is_a?(Integer) } if entity_ids && entity_ids.is_a?(Array)

        if entity_name && entity_name.is_a?(Array)
          return errors[:filter_value] << :'entity should not be empty' if entity_name.empty?

          entity_name.each { |rulename| errors[:entity] << :'entity value must be in string' unless rulename.is_a?(String) }
          validate_export_automation_rules(entity_name)
        end
      end
    end
  end

  def validate_from_to?
    return errors[:'from/to'] << :invalid_time_period unless @request_params[:to].present? && @request_params[:from].present?
    before = Date.parse @request_params[:to]
    since = Date.parse @request_params[:from]
    months = (before.year * 12 + before.month) - (since.year * 12 + since.month)
    years = before.year - since.year
    check_date(since, before)
    return errors[:'from/to'] << :conditions_and_filters_are_only_for_between_six_months if months > 3 && @request_params[:condition]
    return errors[:'from/to'] << :time_limit_exceeded if years > 2
    return errors[:'from<to'] << :invalid_time_range if since > before
  end

  def validate_condition
    return errors[:condition] << :'filter is not present' if @request_params[:condition] && !@request_params[:filter]

    return errors[:condition] << :'condition is not present' if @request_params[:filter].count > 1 && !@request_params[:condition]

    condition = @request_params[:condition].split(' ')
    return errors[:condition] << :'filter and condition is mismatching' if @request_params[:filter].count != condition.each_slice(2).map(&:first).count

    condition.each do |con|
      next if AuditLogConstants::CONDITION_LOWER_CASE.include? con

      errors[:condition] << :'invalid condition' if AuditLogConstants::CONDITION_UPPER_CASE.include? con
      errors[:condition] << :'invalid condition' unless @request_params[:filter].include? con
    end
  end

  def validate_receive_via
    receive_via = @request_params[:receive_via]
    return errors[:receive_via] << :'receive_via should not be empty' if receive_via.blank?
    errors[:receive_via] << :'receive_via value should be email/api' unless AuditLogConstants::RECEIVE_VIA.include? receive_via
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

    def check_date(since, before)
      if since > Time.zone.today || before > Time.zone.today
        errors[:'from/to'] << :'invalid date'
      end
    end
end

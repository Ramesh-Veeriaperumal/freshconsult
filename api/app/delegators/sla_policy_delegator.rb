class SlaPolicyDelegator < BaseDelegator
  include SlaPolicyConstants

  attr_accessor :response_escalations, :resolution_escalations
  validate  :validate_escalation, :validate_conditions, :validate_resolution_escalation_time, :validate_applicable_to

  def initialize(record, options = {})
    super(record)
    @params = options[:params]
    @response_escalations = options[:params][:escalation].try(:[],:response)
    @resolution_escalations = options[:params][:escalation].try(:[],:resolution)
    @valid_agent_ids = Account.current.agents_from_cache.map(&:user_id) << ASSIGNED_AGENT
  end

  def validate_applicable_to
    errors[:applicable_to] = :blank if conditions.empty?
  end

  def validate_conditions
    conditions.each do |field, val|
      condition_hash = SLA_CONDITION[field.to_sym]
      list_ids = Account.current.safe_send(condition_hash[:method])
      list_ids = list_ids.map(&condition_hash[:attribute].to_sym) if condition_hash[:attribute].present?
      invalid_ids = val - list_ids
      add_errors("#{field.pluralize}","invalid_list",invalid_ids) if invalid_ids.present?
    end
  end

  def validate_escalation_level_params(level,err_key)
    ESCALATION_ARRAY_HASH.each do |key,val|
      if key == "escalation_time"
        @resol_esc_time << level[key]
        invalid_input = @valid_escalation_times unless @valid_escalation_times.include?(level[key])
        @valid_escalation_times = @valid_escalation_times.reject {|time| time <= level[key]} if invalid_input.blank?
      else
        invalid_input = level[key] - @valid_agent_ids
      end
      add_errors("#{err_key}[#{key}]",val,invalid_input) if invalid_input.present?
    end
  end

  def validate_escalation
    valid_sla_levels = VALID_SLA_LEVEL
    @resol_esc_time = []
    @valid_escalation_times = VALID_ESCLATION_TIME
    validate_escalation_level_params(response_escalations,"response") if response_escalations.present?
    @valid_escalation_times = VALID_ESCLATION_TIME
    @resol_esc_time = []
    if resolution_escalations.present?
      no_of_levels = resolution_escalations.size
      valid_sla_levels.each do |level_name,level|
        level_params = resolution_escalations[level_name]
          if level_params.present?
            add_errors("resolution[#{level_name}]","blank",nil) and next if level > no_of_levels
            validate_escalation_level_params(level_params,"resolution[#{level_name}]") 
          else
            add_errors("resolution[#{level_name}]","blank",nil) if level < no_of_levels
          end
      end 
    end
  end
  
  def validate_resolution_escalation_time
    dupl_esc_time = []
    dupl_esc_time = @resol_esc_time.select{ |time| @resol_esc_time.count(time) > 1 }.uniq if @resol_esc_time.present?
    if dupl_esc_time.present?
      errors[:"resolution[escalation_time]"] << :duplicate_not_allowed
      @error_options[:"resolution[escalation_time]"] = { name:'escalation time', list: dupl_esc_time.join(', ').to_s }
    end
  end

  def add_errors(err_key,err_type,err_list)
    errors[err_key.to_sym] << err_type.to_sym
    @error_options[err_key.to_sym] = { list: err_list.join(', ') } if err_list.present?
  end
end

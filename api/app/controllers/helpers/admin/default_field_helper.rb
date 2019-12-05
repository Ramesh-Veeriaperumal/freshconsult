module Admin::DefaultFieldHelper
  include Admin::TicketFieldConstants
  include UtilityHelper

  def validate_status_choices_params(_record, choices)
    status_choices = status_choices_by_id
    choices.each do |each_choice|
      data_type_for_status_choice(each_choice)
      next if each_choice[:id].blank? || errors.present?

      absent_in_db_error(:choices, :status_choices, :id) if status_choices[each_choice[:id]].blank?
      missing_param_for_choices(each_choice) if create_action?
    end
    validate_db_uniqueness_for_status_choices(record, choices)
  end

  def data_type_for_status_choice(choice)
    choice.each_pair do |key, value|
      expected_type = CHOICES_EXPECTED_TYPE[(key.to_sym rescue key)]
      unexpected_value_for_attribute(:"choices[#{key}]", key) if expected_type.blank? || ALLOWED_STATUS_CHOICES.exclude?(key)
      if expected_type.present?
        parent_expected_type, children_expected_type = expected_type
        invalid_data_type(:"choices[#{key}]", expected_type, :invalid) unless valid_type?(value, parent_expected_type)
        invalid_data_type(:"choices[#{key}][:each]", children_expected_type, :invalid) if value.is_a?(Array) && value.any? { |x| !valid_type?(x, children_expected_type) }
      end
      validate_status_groups(value) if key == :group_ids
    end
  end

  def validate_status_groups(value)
    unless current_account.shared_ownership_enabled?
      missing_feature_error(:shared_ownership, :group_ids)
    end
    account_group_ids = current_account.groups_from_cache.map(&:id)
    invalid_group_ids = value & account_group_ids
    not_included_error(:group_ids, invalid_group_ids) if invalid_group_ids.present?
  end

  def missing_param_for_choices(choice)
    missing_params = MANDATORY_CHOICE_PARAM_FOR_STATUS_CREATE.select do |expected_key|
      choice[expected_key].blank?
    end
    missing_param_error(:choices, missing_params.join(', ')) if missing_params.present?
  end

  def validate_db_uniqueness_for_status_choices(record, choices)
    return if errors.present?

    position_validation_for_status_choice(record, choices)
    all_status_choices = choices.each_with_object([]) do |each_choice, mapping|
      status_data = status_choices_by_id[each_choice[:id]] || record.ticket_statuses.new
      each_choice = each_choice.dup
      status_data.assign_attributes(build_params(STATUS_CHOICES_PARAMS, each_choice))
      mapping << status_data
    end
    ignored_ids = all_status_choices.map(&:id).compact.sort
    remaining_choices = status_choices_by_id.reject { |key| ignored_ids.bsearch { |id| key <=> id }.present? }
    all_status_choices.push(*remaining_choices.values.flatten)
    name_validation_for_status_choice(record, all_status_choices)
    record.ticket_statuses = [] # clear it so that it does not save multiple times
  end

  def position_validation_for_status_choice(record, choices)
    status_choices = current_account.ticket_status_values_from_cache.map(&:position)
    max_pos = status_choices.last
    min_pos = status_choices.first
    min_pos = 1 if min_pos > 1
    choices.each do |each_choice|
      pos = each_choice[:position]
      choice_position_error(record, :choices, max_pos) if pos.blank? || (pos < min_pos || pos > max_pos)
    end
  end

  def name_validation_for_status_choice(record, choices)
    values = choices.map(&:name)
    duplication_choice_error(record, extract_duplicate_values_in_array(values), :choices) if values.uniq.count != values.count
  end

  def status_choices_by_id
    @status_choices_by_id ||= current_account.ticket_status_values_from_cache.group_by(&:status_id)
  end

  def build_params(constant, param)
    constant.each_with_object({}) do |m, n|
      n[m[0]] = param[m[1]] unless param[m[1]].nil?
    end
  end
end

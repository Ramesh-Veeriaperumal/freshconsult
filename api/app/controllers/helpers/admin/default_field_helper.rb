module Admin::DefaultFieldHelper
  include Admin::TicketFieldConstants
  include Admin::TicketFields::CommonHelper
  include UtilityHelper

  def validate_status_choices(status_field, choices)
    status_params_validation(choices)
    db_status_choice_id_validation(status_field, choices) if errors.blank?
    position_validation_for_status_choice(record, choices) if errors.blank?
    validate_db_uniqueness_for_status_choices(status_field, choices) if errors.blank?
    default_status_choices_validation(status_field, choices) if errors.blank?
    archive_deleted_key_validation(choices) if errors.blank?
  end

  # ticket source validation ensures
  # custom_source feature and ticket_source_revamp launch party are enabled.
  # if value field not present, it is considered as a create request and ensures presence of position and label.
  # if value present, it is considered as a update request and ensures there is a db entry with the value.
  # ensures the data type of all request parameters as expected.
  # Allow only update of position incase of default source
  # ensure uniqueness of source labels(including the soft deleted ones).
  #
  def validate_source_choices(source_field, choices)
    validate_source_features
    source_params_validation(choices) if errors.blank?
    icon_validation(choices) if errors.blank?
    db_source_value_validation(choices) if errors.blank?
    default_source_choices_validation(choices) if errors.blank?
    validate_db_uniqueness_for_source_choices(source_field, choices) if errors.blank?
    validate_source_choice_limit(source_field, choices) if errors.blank?
  end

  private

    def validate_source_features
      missing_feature_error(:ticket_source_revamp) unless current_account.ticket_source_revamp_enabled?
      missing_feature_error(:custom_source) unless current_account.custom_source_enabled?
    end

    def icon_validation(choices)
      max_icon_id = current_account.ticket_source_from_cache.select(&:default).max_by { |x| x.meta[:icon_id] }.meta[:icon_id]
      choices.each do |each_choice|
        next unless each_choice[:icon_id]

        if each_choice[:icon_id] <= max_icon_id
          source_icon_id_error(:choices, nil, max_icon_id + 1)
          break
        end
      end
    end

    def validate_source_choice_limit(record, choices)
      custom_choices_map = current_account.ticket_source_from_cache.visible.custom.map { |i| [i.account_choice_id, i.deleted].flatten }.to_h
      new_non_deleted_choice_count = choices.count { |x| x[:id].blank? && x[:deleted].blank? }
      choices.each do |each_choice|
        next unless each_choice[:id]

        custom_choices_map[each_choice[:id]] = each_choice[:deleted] if each_choice.key?(:deleted)
      end
      total_non_deleted_choices = new_non_deleted_choice_count + custom_choices_map.values.count(false)
      max_limit = Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT
      limit_exceeded_error(record.label, max_limit, :ticket_choices_exceeded_limit) if total_non_deleted_choices > max_limit
    end

    def archive_deleted_key_validation(choices)
      choices.each do |each_choice|
        if each_choice.key?(:id)
          errors[:choices] << :archive_deleted_error if each_choice.key?(:archived) && each_choice.key?(:deleted)
        elsif each_choice.key?(:archived) || each_choice.key?(:deleted)
          errors[each_choice.key?(:archived) ? :archived : :deleted] << :invalid_field
        end
      end
    end

    def default_choice_invalid_params(db_choice, param_choice)
      invalid_params = param_choice.keys.map(&:to_sym) - DEFAULT_STATUS_CHOICES_PARAMS_ALLOWED - [:id]
      if db_choice.status_id == Helpdesk::Ticketfields::TicketStatus::PENDING && invalid_params.length > 1
        invalid_params -= PENDING_STATUS_CHOICE_ALLOWED_PARAMS
        unexpected_value_for_attribute(db_choice.name.to_s.intern, invalid_params.join(', '))
      elsif invalid_params.present? && db_choice.status_id != 3
        unexpected_value_for_attribute(db_choice.name.to_s.intern, invalid_params.join(', '))
      end
    end

    def default_status_choices_validation(status_field, choices)
      choices.each do |each_choice|
        next if DEFAULT_STATUS_CHOICE_IDS.exclude?(each_choice[:id])

        db_choice = status_choices_by_id(status_field)[each_choice[:id]].first
        default_choice_invalid_params(db_choice, each_choice)
      end
    end

    def default_source_choices_validation(choices)
      source_choices = source_choices_by_id
      choices.each do |each_choice|
        next unless each_choice[:id]

        db_choice = source_choices[each_choice[:id]].first
        check_update_params_for_default_sources(each_choice) if db_choice.default
      end
    end

    def check_update_params_for_default_sources(choices)
      invalid_field = choices.keys.map(&:to_sym) - ALLOWED_FIELDS_FOR_DEFAULT_SOURCE_UPDATE
      default_field_error(:id, :choice) if invalid_field.present?
    end

    def data_type_for_status_choice(choice)
      choice.each_pair do |key, value|
        key = key.to_s.intern
        return unexpected_value_for_attribute(:"choices[#{key}]", key) if ALLOWED_STATUS_CHOICES.exclude?(key)

        valid_data_type?(name, key, value, CHOICES_EXPECTED_TYPE[key])
      end
    end

    def data_type_for_source_choice(choice)
      choice.each_pair do |key, value|
        key = key.to_s.intern
        return unexpected_value_for_attribute(:"choices[#{key}]", key) if ALLOWED_SOURCE_CHOICES.exclude?(key)

        unless match_type?(value, SOURCE_CHOICES_EXPECTED_TYPE[key])
          invalid_data_type("choice[#{key}]".intern, SOURCE_CHOICES_EXPECTED_TYPE[key], DATA_TYPE_MAPPING[value.class])
          break
        end
      end
    end

    def missing_param_for_choices(choice)
      missing_params = MANDATORY_CHOICE_PARAM_FOR_STATUS_CREATE.select do |expected_key|
        choice[expected_key].blank?
      end
      missing_param_error(:choices, missing_params.join(', ')) if missing_params.present?
    end

    def missing_param_for_source_choices(choice)
      missing_params = MANDATORY_CHOICE_PARAM_FOR_SOURCE_CREATE.select do |expected_key|
        choice[expected_key].blank?
      end
      missing_param_error(:choices, missing_params.join(', ')) if missing_params.present?
    end

    def status_params_validation(choices)
      choices.each do |each_choice|
        next if errors.present?

        data_type_for_status_choice(each_choice)
        missing_param_for_choices(each_choice) unless each_choice.key?(:id)
      end
    end

    def source_params_validation(choices)
      choices.each do |each_choice|
        break if errors.present?
        missing_param_for_source_choices(each_choice) unless each_choice.key?(:id)
        data_type_for_source_choice(each_choice) if errors.blank?
      end
    end

    def validate_status_groups(value)
      unless current_account.shared_ownership_enabled?
        missing_feature_error(:shared_ownership, :group_ids)
      end
      account_group_ids = current_account.groups_from_cache.map(&:id)
      invalid_group_ids = value - account_group_ids
      not_included_error(:group_ids, invalid_group_ids.join(', ')) if invalid_group_ids.present?
    end

    def db_status_choice_id_validation(status_field, choices)
      status_choices = status_choices_by_id(status_field)
      choices.each do |each_choice|
        next if !each_choice.key?(:id) || errors.present?

        absent_in_db_error(:choices, :status_choices, "id `#{each_choice[:id]}`") if status_choices[each_choice[:id]].blank?
        validate_status_groups(each_choice[:group_ids]) if each_choice.key?(:group_ids).present?
      end
    end

    def db_source_value_validation(choices)
      source_choices = source_choices_by_id
      choices.each do |each_choice|
        next if !each_choice.key?(:id) || errors.present?

        absent_in_db_error(:choices, :source_choice, "id `#{each_choice[:id]}`") if source_choices[each_choice[:id]].blank?
      end
    end

    def separate_old_and_new_choices(record, choices)
      old_choices = {}
      new_choices = []
      choices.each do |each_choice|
        status_data = (status_choices_by_id(record)[each_choice[:id]] || [])[0]
        if status_data.present?
          old_choices[status_data[:status_id]] = each_choice[:value] || status_data[:name]
        else
          new_choices << each_choice[:value]
        end
      end
      [old_choices, new_choices]
    end

    def validate_db_uniqueness_for_status_choices(record, choices)
      old_choices, new_choices = separate_old_and_new_choices(record, choices)
      ignored_ids = old_choices.keys.compact.sort
      remaining_choices = status_choices_by_id(record).reject { |key| ignored_ids.bsearch { |id| key <=> id }.present? }
      all_status_choices = remaining_choices.values.flatten.map(&:name).compact
      all_status_choices.push(*new_choices).push(*old_choices.values.flatten)
      name_validation_for_status_choice(record, all_status_choices)
    end

    def validate_db_uniqueness_for_source_choices(source, choices)
      source_name_map = current_account.ticket_source_from_cache.map { |i| [i.name, i.account_choice_id].flatten }.to_h
      choices.each do |each_choice|
        next if each_choice[:label].blank? || (each_choice[:id] && source_name_map[each_choice[:label]] == each_choice[:id])

        if source_name_map[each_choice[:label]]
          duplication_choice_error(source, [each_choice[:label]], :choices, 'label')
        else
          source_name_map[each_choice[:label]] = each_choice[:id].presence || 0
        end
      end
    end

    def position_validation_for_status_choice(record, choices)
      new_choices_count = choices.count { |each_choice| !each_choice.key?(:id) }
      max_allowed_position = status_choices_by_id(record).values.flatten.max_by(&:position).position + new_choices_count
      choices.each do |each_choice|
        pos = each_choice[:position] || 1
        choice_position_error(record, :choices, max_allowed_position) if pos < 1 || pos > max_allowed_position
      end
    end

    def name_validation_for_status_choice(record, values)
      duplication_choice_error(record, extract_duplicate_values_in_array(values), :choices) if values.uniq.count != values.count
    end

    def status_choices_by_id(ticket_field)
      @status_choices_by_id ||= begin
        field_status = ticket_field.ticket_field_statuses_from_cache.map { |x| x.status_id; x }
        field_status.group_by(&:status_id)
      end
    end

    def source_choices_by_id
      @source_choices_by_id ||= begin
        current_account.ticket_source_from_cache.group_by(&:account_choice_id)
      end
    end
end

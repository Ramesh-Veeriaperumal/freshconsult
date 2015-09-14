class Helpers::TicketsValidationHelper
  class << self

    def ticket_type_values
      Account.current ? Account.current.ticket_types_from_cache.map(&:value) : []
    end

    def ticket_custom_field_keys(flexifields)
      flexifields.map(&:flexifield_alias)
    end

    def choices_validatable_custom_fields(delegator)
      delegator.ff.map(&:ticket_field).select! { |c| (['custom_dropdown', 'nested_field'].include?(c.field_type)) }
    end

    def data_type_validatable_custom_fields(delegator)
      delegator.ff.map(&:ticket_field).select! { |c| (['custom_dropdown', 'nested_field'].exclude?(c.field_type)) }
    end

    def dropdown_choices_by_field_name(delegator)
      delegator.ff.map(&:ticket_field).select!{|tf| 
        tf.flexifield_def_entry_id != nil && tf.field_type == 'custom_dropdown'}.map! { |x| 
          [x.name.to_sym, x.choices.flatten.uniq] }.to_h
    end

    def check_box_type_custom_field_names(flexifields)
      flexifields.select { |x| x.flexifield_coltype == 'checkbox' }.map(&:flexifield_alias)
    end

    def nested_fields_choices_by_name(delegator)
      nested_fields = get_nested_fields(delegator).to_h
      {
        first_level_choices: nested_fields.map { |x| [x.first, x.last.keys] }.to_h,
        second_level_choices: nested_fields.map { |x| [x.first, x.last.map { |t| [t.first, t.last.keys] }.to_h] }.to_h,
        third_level_choices: nested_fields.map { |x| [x.first, x.last.map(&:last).reduce(&:merge)] }.to_h
      }
    end

    def get_nested_fields(delegator)
      delegator.ff.map(&:ticket_field).select!{|f| 
        f.flexifield_def_entry_id != nil && f.field_type == 'nested_field'}.map!{|x|
          [x.name, x.api_nested_choices]}
    end

    # compute the size of attachments associated with the record.
    def attachment_size(item)
      item.try(:attachments).try(:sum, &:content_file_size).to_i
    end
  end
end

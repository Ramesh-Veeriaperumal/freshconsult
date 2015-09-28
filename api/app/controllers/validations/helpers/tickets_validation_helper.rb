class Helpers::TicketsValidationHelper
  class << self

    def ticket_type_values
      Account.current ? Account.current.ticket_types_from_cache.map(&:value) : []
    end

    def ticket_custom_field_keys(ticket_fields)
      ticket_fields.select{|x| !x.default}.collect(&:name)
    end

    def choices_validatable_custom_fields(delegator)
      delegator.ticket_fields.select { |c| (['custom_dropdown', 'nested_field'].include?(c.field_type)) }
    end

    def data_type_validatable_custom_fields(delegator)
      delegator.ticket_fields.select { |c| (!c.default && ['custom_dropdown', 'nested_field'].exclude?(c.field_type)) }
    end

    def dropdown_choices_by_field_name
      Account.current.custom_dropdown_fields_from_cache.collect { |x| 
        [x.name.to_sym, x.choices.flatten.uniq] }.to_h
    end

    def check_box_type_custom_field_names(ticket_fields)
      ticket_fields.select { |x| x.field_type == 'custom_checkbox' }.map(&:name)
    end

    def nested_fields_choices_by_name
      nested_fields = Account.current.nested_fields_from_cache.collect { |x| [x.name, x.formatted_nested_choices] }.to_h
      {
        first_level_choices: nested_fields.map { |x| [x.first, x.last.keys] }.to_h,
        second_level_choices: nested_fields.map { |x| [x.first, x.last.map { |t| [t.first, t.last.keys] }.to_h] }.to_h,
        third_level_choices: nested_fields.map { |x| [x.first, x.last.map(&:last).reduce(&:merge)] }.to_h
      }
    end

    # compute the size of attachments associated with the record.
    def attachment_size(item)
      item.try(:attachments).try(:sum, &:content_file_size).to_i
    end
  end
end

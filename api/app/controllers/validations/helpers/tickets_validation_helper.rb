class Helpers::TicketsValidationHelper
  class << self
    def ticket_type_values
      Account.current ? Account.current.ticket_types_from_cache.map(&:value) : []
    end

    def name_mapping(ticket_fields)
      ticket_fields.reject(&:default).each_with_object({}) { |tf, hash| hash[tf.name.to_sym] = TicketDecorator.without_account_id(tf.name).to_sym }
    end

    def custom_dropdown_fields(delegator)
      delegator.ticket_fields.select { |c| (['custom_dropdown', 'nested_field'].include?(c.field_type)) }
    end

    def custom_non_dropdown_fields(delegator)
      delegator.ticket_fields.select { |c| (!c.default && ['custom_dropdown', 'nested_field'].exclude?(c.field_type)) }
    end

    def custom_dropdown_field_choices
      Account.current.custom_dropdown_fields_from_cache.collect do |x|
        [x.name.to_sym, x.choices.flatten.uniq]
      end.to_h
    end

    def custom_nested_field_choices
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

    def custom_checkbox_names(ticket_fields)
      ticket_fields.select { |x| x.field_type.to_sym == :custom_checkbox }.map(&:name)
    end
  end
end

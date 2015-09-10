class ContactFieldDecorator
  class << self
    def contact_field_choices(contact_field)
      case contact_field.field_type.to_s
      when 'default_language', 'default_time_zone'
        contact_field.choices.map { |x| x.values.reverse }.to_h
      when 'custom_dropdown' # not_tested
        contact_field.choices.map { |x| x[:value] }
      end
    end

    def default_contact_field?(contact_field)
      contact_field.column_name == 'default'
    end
  end
end

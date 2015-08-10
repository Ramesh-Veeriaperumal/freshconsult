class Helpers::ContactsValidationHelper
  class << self
    def custom_contact_fields
      Account.current.contact_form.custom_contact_fields.select { |c| c.field_type != :custom_dropdown }
    end

    def custom_contact_dropdown_fields
      Account.current.contact_form.custom_contact_fields.select { |c| c.field_type == :custom_dropdown }.collect { |x| [x.name.to_sym, x.choices.collect { |t| t[:value] }] }.to_h
    end

    def custom_contact_fields_for_delegator
      Account.current.contact_form.custom_contact_fields.select { |c| c.field_type == :custom_dropdown }
    end
  end
end

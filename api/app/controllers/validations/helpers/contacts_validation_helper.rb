class Helpers::ContactsValidationHelper
  class << self
    def custom_contact_fields
      custom_fields.select { |c| c.field_type != :custom_dropdown }
    end

    def custom_contact_dropdown_fields
      custom_contact_fields_for_delegator.map { |x| [x.name.to_sym, x.choices.map { |t| t[:value] }] }.to_h
    end

    def custom_contact_fields_for_delegator
      custom_fields.select { |c| c.field_type == :custom_dropdown }
    end

    def custom_fields
      Account.current.contact_form.custom_contact_fields
    end
  end
end

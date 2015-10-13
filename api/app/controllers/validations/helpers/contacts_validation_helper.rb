class Helpers::ContactsValidationHelper
  class << self
    
    def default_contact_fields
      Account.current.contact_form.default_contact_fields
    end

    def custom_contact_fields
      Account.current.contact_form.custom_contact_fields.select { |c| c.field_type != :custom_dropdown }
    end

    def custom_contact_dropdown_fields
      custom_contact_fields_for_delegator.map { |x| [x.name.to_sym, x.choices.map { |t| t[:value] }] }.to_h
    end

    def custom_contact_fields_for_delegator
      Account.current.contact_form.custom_contact_fields.select { |c| c.field_type == :custom_dropdown }
    end

    def default_field_validations
      {
        client_manager: { data_type: { rules: 'Boolean', ignore_string: :allow_string_param }},
        job_title:  { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        language: { custom_inclusion: { in: ContactConstants::LANGUAGES }},
        tag_names:  { data_type: { rules: Array }, array: { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }, string_rejection: { excluded_chars: [','] }},
        time_zone: { custom_inclusion: { in: ContactConstants::TIMEZONES }},
        phone: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        mobile: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        address: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        twitter_id: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        email: { format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }
      }
    end
  end
end

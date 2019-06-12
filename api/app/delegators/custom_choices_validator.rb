# Validator for the custom dropdown choices.
# TODO: Passing internal_values and make data_type validation: dynamic.
class CustomChoicesValidator < BaseChoicesValidator
  ATTRIBUTES = ['id', 'value'].freeze
  OPTIONS = {
    id: {
      attributes: [:id],
      rules: Integer,
      allow_nil: false
    },
    value: {
      attributes: [:value],
      rules: String,
      allow_nil: false,
      required: true
    }
  }.freeze

  def validate_each
    return ERROR unless validate_choices(value)
  end

  private

    def validate_choices(choices)
      choices.each { |choice| return ERROR unless validate_properties_of(choice) }
      validate_uniqueness_of(choices)
    end

    # validates properties and type.
    def validate_properties_of(choice)
      return ERROR if validate_keys(choice)

      ATTRIBUTES.each do |attr|
        attr_value = choice[attr]
        next unless attr_value

        DataTypeValidator.new(OPTIONS[attr.to_sym].dup).validate_value(record, attr_value)
        return ERROR if record.errors[:choices].present?
      end
      true
    end

    def validate_keys(choice)
      record_error && (return ERROR) if choice.except(*self.class::ATTRIBUTES).present?
    end

    # validates uniqueness of choices base on attributes.
    def validate_uniqueness_of(choices_belonging_to_single_parent)
      CustomUniquenessValidator.new(attributes: PROPERTIES).validate_value(record, choices_belonging_to_single_parent)
      record.errors[:choices].blank?
    end

    def error_code
      :invalid_choices_field
    end

    def message
      :invalid_choices_field
    end
end

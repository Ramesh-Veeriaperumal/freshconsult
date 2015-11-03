class ArrayValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, values)
    return unless values.is_a? Array
    values.each do |value|
      options.each do |key, args|
        next if record.errors[attribute].present?
        validator_options = { attributes: attribute }
        validator_options.merge!(args) if args.is_a?(Hash)

        next if value.nil? && validator_options[:allow_nil]
        next if value.blank? && validator_options[:allow_blank]

        validator_class_name = "#{key.to_s.camelize}Validator"
        validator = validator_class(validator_class_name).new(validator_options)
        validator.validate_each(record, attribute, value)
      end
    end
  end

  private

    def validator_class(validator_class_name)
      validator_class_name.constantize
    rescue NameError
      "ActiveModel::Validations::#{validator_class_name}".constantize
    end
end

class ArrayValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, values)
    return unless values.is_a? Array
    values.each do |value|
      options.each do |key, args|
        validator_options = { attributes: attribute }
        validator_options.merge!(args) if args.is_a?(Hash)

        next if value.nil? && validator_options[:allow_nil]
        next if value.blank? && validator_options[:allow_blank]

        validator_class_name = "#{key.to_s.camelize}Validator"
        validator_class = get_validator_class(validator_class_name)
        validator = validator_class.new(validator_options)
        validator.validate_each(record, attribute, value)
      end
    end
  end

  private
    def get_validator_class(validator_class_name)
      validator_class_name.constantize
    rescue NameError
      "ActiveModel::Validations::#{validator_class_name}".constantize
    end
end

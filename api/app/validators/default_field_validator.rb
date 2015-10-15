class DefaultFieldValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    # return if attribute has already an error.
    return if record.errors[attribute].present? 

    # check if attribute is required by intersecting with required fields list.
    required_field = @required_fields.detect { |x| x.name == attribute.to_s }
    field_validation = @default_field_validations[attribute]
    return unless required_field || field_validation

    # call validators if validations already exists for the attribute. else required_valdiator.
    if field_validation
      call_validators(record, attribute, field_validation, required_field.present?)
    else
      required_validator(record, attribute)
    end

  end

  def validate(record)
    # Assign list of required_fields before calling validate_each for each attribute
    @required_fields = proc_to_object(options[:required_fields], record)
    @default_field_validations = proc_to_object(options[:field_validations], record)
    super

    #Assign empty array after validate_each of all attributes are over as validator object will be reused in subsequent calls.
    ensure
      @required_fields = []
      @default_field_validations = []
  end

  # Call validators for each validation in field_validation array.
  def call_validators(record, attribute, field_validation, required)
    field_validation.each do |validator, validator_options|
      
      # return if attribute has alread
      next if record.errors[attribute].present?

      # merge required & allow_nil option if the field is required
      options_hash = {required: required, attributes: attribute, allow_nil: !required}.merge(validator_options)
      
      case validator
      when :custom_inclusion
        inclusion_validator(record, options_hash)
      when :custom_numericality 
        custom_numericality_validator(record, options_hash)
      when :data_type
        data_type_validator(record, options_hash)
      when :array
        array_options = add_allow_nil_option(validator_options).merge(attributes: attribute)
        array_validator(record, array_options)
      when :length
        required_validator(record, attribute) if required 
        length_validator(record, options_hash) if record.errors[attribute].blank?
      when :format
        required_validator(record, attribute) if required 
        format_validator(record, options_hash) if record.errors[attribute].blank?
      when :string_rejection
        required_validator(record, attribute) if required
        string_rejection_validator(record, options_hash)
      else
        raise ArgumentError.new("No validator with this #{validator} name exists in #{self.class}")
      end
    end
  end

  # Add allow nil option for the array element validators
  def add_allow_nil_option(options_hash)
    options_hash.map {|key, value| [key, (value.is_a?(Hash) ? value.merge(allow_nil: true) : value)]}.to_h
  end

  def proc_to_object(proc, record = nil)
    proc.respond_to?(:call) ? proc.call(record) : proc
  end


  def required_validator(record, attribute, options_hash=options)
    RequiredValidator.new(options_hash.merge(attributes: attribute, allow_nil: false, allow_blank: false)).validate(record)
  end

  def inclusion_validator(record, options_hash)
    CustomInclusionValidator.new(options_hash).validate(record)
  end

  def length_validator(record, options_hash)
    ActiveModel::Validations::LengthValidator.new(options_hash).validate(record)
  end

  def custom_numericality_validator(record, options_hash)
    CustomNumericalityValidator.new(options_hash).validate(record)
  end

  def string_rejection_validator(record, options_hash)
    StringRejectionValidator.new(options_hash).validate(record)
  end

  def array_validator(record, options_hash)
    ArrayValidator.new(options_hash).validate(record)
  end

  def format_validator(record, options_hash)
    ActiveModel::Validations::FormatValidator.new(options_hash).validate(record)
  end

  def data_type_validator(record, options_hash)
    DataTypeValidator.new(options_hash).validate(record)
  end

end

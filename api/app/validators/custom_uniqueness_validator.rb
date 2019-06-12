# TODO: Single error consideration.
# For eg - attributes[0] = {:choices=>[:id, :value]}, values = Array of input_choices_hash.
# Used to validate uniquness of attributes in given array of objects. For instance - uniqueness of id, value for choices[].
class CustomUniquenessValidator < ApiValidator
  # considering only one attribute is given
  def validate_value(record, values)
    @record = record
    related_object_with_attributes_hash = attributes[0]
    values.present? &&
      related_object_with_attributes_hash.each { |object_name, attributes| return false unless validate_objects_on_attributes(attributes, object_name, values) }
    true
  end

  private

    def validate_objects_on_attributes(req_attributes, object_name, input_objects_hash)
      @attribute = object_name
      req_attributes.each do |req_attribute|
        @value = input_objects_hash.collect { |object_hash| object_hash[req_attribute.to_s] }.compact
        return false unless validate_attribute
      end
    end

    # return is not clear based on the method name.
    def validate_attribute
      if invalid?
        record_error
        false
      else
        true
      end
    end

    # validate for a array containing objects[attribute]
    def invalid?
      detected_elements = Set.new
      valid = true
      value.each { |val| detected_elements.include?(val) ? valid = false && break : detected_elements.add(val) }
      !valid
    end

    def error_code
      :duplicate_choices unless attribute_defined?
    end

    def message
      :duplicate_choices
    end

    def skip_validation?(_validator_options = options)
      errors_present?
    end
end

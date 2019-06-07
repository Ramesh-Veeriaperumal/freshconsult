# Recheck the error rendering.
# TODO: soft delete consideration.
class NestedChoicesValidator < CustomChoicesValidator
  ATTRIBUTES = ['id', 'value', 'choices'].freeze
  def validate_each
    return ERROR unless validate_nested_choices(value)

    choice_ids = value.collect { |value| value['id'] }.compact
    return ERROR unless validate_id_uniqueness(choice_ids)
  end

  private

    def validate_nested_choices(choices, level = 0)
      return true if level > 2

      choices.each do |choice|
        return ERROR unless validate_properties_of(choice) && validate_nested_choices(choice['choices'], level + 1)
      end
      validate_uniqueness_of(choices)
    end

    # validates and checks that there are no duplicate id's.
    def validate_id_uniqueness(choice_ids)
      valid = true
      detected_elements = Set.new
      choice_ids.each { |val| detected_elements.include?(val) ? valid = false && break : detected_elements.add(val) }
      valid
    end
end

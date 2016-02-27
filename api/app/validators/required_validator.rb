# Overriding defualt validator to add custom message to presence validation.

class RequiredValidator < ApiValidator

  def invalid?
    # return if value is there or a falseclass
    !present_or_false?
  end

  def message
    attribute_defined? ? :blank : :missing_field
  end
end

# Check if value is not present.

class CustomAbsenceValidator < ApiValidator
  def message
    :present
  end

  def invalid?
    record.instance_variable_defined?("@#{attribute}")
  end
end

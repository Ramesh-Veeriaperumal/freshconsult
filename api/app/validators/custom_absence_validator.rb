# Check if value is not present.

class CustomAbsenceValidator < ApiValidator

  private

    def message
      :present
    end

    def invalid?
      record.instance_variable_defined?("@#{attribute}")
    end

    def error_code
      :incompatible_field
    end

    def allow_unset?
      !record.instance_variable_get("@#{attribute}_set")
    end
end

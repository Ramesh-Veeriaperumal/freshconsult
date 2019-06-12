# Base validator for choices.
class BaseChoicesValidator < ApiValidator
  # Dynamic or override?
  PROPERTIES = { choices: [:id, :value] }.freeze
  ERROR = false

  # redefine below in each of the choices validator.
  def validate_each; end

  private

    def error_code
      :duplicate_choices
    end

    def message
      :duplicate_choices
    end
end

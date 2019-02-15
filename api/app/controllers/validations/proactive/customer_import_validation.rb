module Proactive
  class CustomerImportValidation < ::CustomerImportValidation

    attr_accessor :attachment_id, :attachment_file_name

    validates :attachment_id, data_type: { rules: Integer, required: true }, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }

    validates :attachment_file_name, data_type: { rules: String, required: true }

    def initialize(request_params, item, allow_string_param = false)
      super(request_params, item, allow_string_param)
    end
  end
end
module ApiDiscussions
  class MonitorValidation < ApiValidation
    attr_accessor :user_id
    validates :user_id, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param }

    def initialize(request_params, item = nil, allow_string_param = false)
      super(request_params, item, allow_string_param)
    end
  end
end

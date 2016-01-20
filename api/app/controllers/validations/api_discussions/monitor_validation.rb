module ApiDiscussions
  class MonitorValidation < ApiValidation
    attr_accessor :user_id
    validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, greater_than: 0 }

    def initialize(request_params, item = nil, allow_string_param = false)
      super(request_params, item, allow_string_param)
    end
  end
end

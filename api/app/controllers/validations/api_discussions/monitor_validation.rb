module ApiDiscussions
  class MonitorValidation < ApiValidation
    attr_accessor :user_id
    validates :user_id, custom_numericality: { allow_nil: true, ignore_string: :string_param }

    def initialize(request_params)
      super(request_params, nil)
    end
  end
end

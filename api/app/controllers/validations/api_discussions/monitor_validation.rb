module ApiDiscussions
  class MonitorValidation < ApiValidation
    attr_accessor :user_id
    validates :user_id, numericality: { allow_nil: true, only_integer: true }

    def initialize(request_params)
      super(request_params, nil)
    end
  end
end

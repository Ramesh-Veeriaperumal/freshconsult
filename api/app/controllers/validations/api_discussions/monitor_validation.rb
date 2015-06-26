module ApiDiscussions
  class MonitorValidation < ApiValidation
    attr_accessor :user_id
    validates :user_id, numericality: true, allow_nil: true

    def initialize(request_params)
      super(request_params, nil)
    end
  end
end

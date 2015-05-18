module ApiDiscussions
  class MonitorValidation
    include ActiveModel::Validations

    attr_accessor :user_id
    validates :user_id, numericality: true, allow_nil: true

    def initialize(controller_params)
      @user_id = controller_params['user_id']
    end
  end
end

module ApiDiscussions
  class PostValidation < ApiValidation
    include ActiveModel::Validations

    attr_accessor :user_id, :body_html, :topic_id, :created_at, :updated_at, :answer
    validates :body_html, presence: true
    validates_with DateTimeValidator, fields: [:created_at, :updated_at], allow_nil: true
    validates :answer, inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :user_id, numericality: { allow_nil: true }
    validates :topic_id, numericality: true

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end

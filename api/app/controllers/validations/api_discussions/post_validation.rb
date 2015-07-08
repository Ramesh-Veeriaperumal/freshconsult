module ApiDiscussions
  class PostValidation < ApiValidation
    attr_accessor :user_id, :body_html, :topic_id, :answer
    validates :body_html, presence: true
    validates :answer, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :user_id, numericality: { allow_nil: true }
    validates :topic_id, numericality: true
    validates :body_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end

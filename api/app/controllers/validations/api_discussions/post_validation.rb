module ApiDiscussions
  class PostValidation < ApiValidation
    attr_accessor :body_html, :topic_id, :answer
    validates :body_html, required: true
    validates :answer, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :topic_id, required: { allow_nil: false, message: 'required_and_numericality' }
    validates :topic_id, numericality: true, allow_nil: true
    validates :body_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end

    def attributes_to_be_stripped
      DiscussionConstants::POST_FIELDS_TO_BE_STRIPPED
    end
  end
end

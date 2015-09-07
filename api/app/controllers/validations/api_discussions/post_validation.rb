module ApiDiscussions
  class PostValidation < ApiValidation
    attr_accessor :body_html, :answer
    validates :body_html, required: true
    validates :answer, data_type: { rules: 'Boolean', allow_blank: true }
    validates :body_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end

    def attributes_to_be_stripped
      DiscussionConstants::POST_FIELDS_TO_BE_STRIPPED
    end
  end
end

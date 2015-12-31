module ApiDiscussions
  class ApiCommentValidation < ApiValidation
    attr_accessor :body_html, :answer
    validates :body_html, required: true
    validates :answer, data_type: { rules: 'Boolean' }
    validates :body_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end

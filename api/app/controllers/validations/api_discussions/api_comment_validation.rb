module ApiDiscussions
  class ApiCommentValidation < ApiValidation
    CHECK_PARAMS_SET_FIELDS = %w(answer).freeze

    attr_accessor :body_html, :answer
    validates :answer, custom_absence: { allow_nil: false, message: :cannot_set_answer }, if: -> { DiscussionConstants::QUESTION_STAMPS.exclude?(@stamp_type) }, on: :update
    validates :answer, data_type: { rules: 'Boolean' }, on: :update
    validates :body_html, data_type: { rules: String, required: true }

    def initialize(request_params, item)
      super(request_params, item)
      @stamp_type = item.topic.stamp_type if item
    end
  end
end

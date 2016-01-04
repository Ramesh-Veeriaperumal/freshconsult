module ApiDiscussions
  class ApiCommentValidation < ApiValidation
    attr_accessor :body_html, :answer
    validates :body_html, required: true
    validates :answer, custom_absence: { allow_nil: false, message: :incompatible_field }, if: -> do 
      @answer_set && 
validates :answer, data_type: { rules: 'Boolean' }, on: :update
    validates :body_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
      check_params_set(request_params, item)
      @stamp_type = item.topic.stamp_type if item
    end
  end
end

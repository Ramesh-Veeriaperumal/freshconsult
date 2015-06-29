module ApiDiscussions
  class TopicValidation < ApiValidation
    attr_accessor :title, :forum_id, :user_id, :sticky, :locked,
                  :stamp_type, :message_html
    validates :title, :message_html, presence: true
    validates :sticky, :locked, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :forum_id, numericality: true
    validates :stamp_type, :user_id, numericality: { allow_nil: true }

    def initialize(request_params, item)
      @message_html = item.try(:first_post).try(:body_html) if item
      super(request_params, item)
    end
  end
end

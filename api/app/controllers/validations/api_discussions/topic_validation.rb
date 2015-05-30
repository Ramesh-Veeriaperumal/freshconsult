module ApiDiscussions
  class TopicValidation < ApiValidation
    include ActiveModel::Validations

    attr_accessor :title, :forum_id, :user_id, :created_at, :updated_at, :sticky, :locked,
                  :stamp_type, :message_html
    validates :title, :message_html, presence: true
    validates_with DateTimeValidator, fields: [:created_at, :updated_at], allow_nil: true
    validates :sticky, :locked, inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :forum_id, numericality: true
    validates :stamp_type, :user_id, numericality: { allow_nil: true }

    def initialize(request_params, item)
      @message_html = item.try(:first_post).try(:body_html) if item
      super(request_params, item)
    end
  end
end

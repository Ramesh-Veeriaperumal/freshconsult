module ApiDiscussions
  class TopicValidation < ApiValidation
    attr_accessor :title, :forum_id, :sticky, :locked,
                  :stamp_type, :message_html
    validates :title, :message_html, required: true
    validates :forum_id, required: { allow_nil: false, message: 'required_and_numericality' }
    validates :sticky, :locked, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
    validates :forum_id, numericality: true, allow_nil: true
    validates :stamp_type, numericality: { allow_nil: true }

    def initialize(request_params, item)
      @message_html = item.try(:first_post).try(:body_html) if item
      super(request_params, item)
      @sticky = item.sticky.to_s.to_bool if item && request_params['sticky'].nil?
    end
  end
end

module ApiDiscussions
  class TopicValidation < ApiValidation
    attr_accessor :title, :forum_id, :sticky, :locked,
                  :stamp_type, :message_html
    validates :title, required: true, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
    validates :message_html, required: true
    validates :forum_id, required: { allow_nil: false, message: :required_and_numericality }, on: :update
    validates :sticky, :locked, data_type: { rules: 'Boolean', allow_nil: true }
    validates :forum_id, custom_numericality: { allow_nil: true }, on: :update
    validates :stamp_type, custom_numericality: { allow_nil: true }

    def initialize(request_params, item)
      @message_html = item.try(:first_post).try(:body_html) if item
      super(request_params, item)
      @sticky = item.sticky.to_s.to_bool if item && request_params['sticky'].nil?
    end

    def attributes_to_be_stripped
      DiscussionConstants::TOPIC_FIELDS_TO_BE_STRIPPED
    end
  end
end

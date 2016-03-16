module ApiDiscussions
  class TopicValidation < ApiValidation
    attr_accessor :title, :forum_id, :sticky, :locked,
                  :stamp_type, :message_html
    validates :title, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
    validates :message_html, data_type: { rules: String, required: true }
    validates :sticky, :locked, data_type: { rules: 'Boolean' }
    validates :forum_id, custom_numericality: { only_integer: true, greater_than: 0, required: true }, on: :update
    validates :stamp_type, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true }

    def initialize(request_params, item)
      @message_html = item.try(:first_post).try(:body_html) if item
      super(request_params, item)
      @sticky = item.sticky.to_s.to_bool if item && request_params['sticky'].nil?
    end

    def attributes_to_be_stripped
      DiscussionConstants::TOPIC_ATTRIBUTES_TO_BE_STRIPPED
    end
  end
end

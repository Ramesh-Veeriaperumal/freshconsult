class TwitterReplyValidation < ApiValidation
  attr_accessor :body, :tweet_type, :twitter_handle_id, :agent_id

  validates :tweet_type, data_type: { rules: String, required: true }, custom_inclusion: { in: ApiConstants::TWITTER_REPLY_TYPES }
  validates :body, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::TWEET_MAX_LENGTH }, if: -> { (@tweet_type || '').to_sym != :dm }
  validates :body, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::TWITTER_DM_MAX_LENGTH }, if: -> { (@tweet_type || '').to_sym == :dm }
  validates :twitter_handle_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, required: true }
  validates :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validate :twitter_ticket?

  def initialize(request_params, item = nil, allow_string_param = false)
    @item = item
    super
  end

  def twitter_ticket?
    errors[:ticket_id] << :not_a_twitter_ticket unless @item.twitter?
  end
end

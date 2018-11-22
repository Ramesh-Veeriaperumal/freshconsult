class Bot::FeedbackValidation < ApiValidation
  attr_accessor :useful, :start_at, :end_at, :query_id, :direction

  validates :useful, custom_inclusion: { in: BotFeedbackConstants::FEEDBACK_USEFUL_TOKEN_BY_KEY.keys, ignore_string: :allow_string_param }, on: :index
  validates :start_at, date_time: { allow_nil: false, required: true }, on: :index
  validates :end_at, date_time: { allow_nil: false, required: true }, on: :index
  validate  :validate_time_period, if: -> { errors[:start_at].blank? && errors[:end_at].blank? }, on: :index
  validates :query_id, data_type: { rules: String }, on: :chat_history
  validates :direction, data_type: { rules: String }, custom_inclusion: { in: BotFeedbackConstants::CHAT_HISTORY_DIRECTIONS }, on: :chat_history

  def validate_time_period
    errors[:end_at] << :unanswered_time_period_invalid if end_at < start_at
  end
end

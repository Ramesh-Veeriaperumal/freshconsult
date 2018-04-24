class Bot::FeedbackValidation < ApiValidation
  attr_accessor :useful, :start_at, :end_at

  validates :useful, custom_inclusion: { in: BotFeedbackConstants::FEEDBACK_USEFUL_TOKEN_BY_KEY.keys, ignore_string: :allow_string_param }, on: :index
  validates :start_at, date_time: { allow_nil: false, required: true }, on: :index
  validates :end_at, date_time: { allow_nil: false, required: true }, on: :index
  validate  :validate_time_period, if: -> { errors[:start_at].blank? && errors[:end_at].blank? }, on: :index

  def validate_time_period
    errors[:end_at] << :unanswered_time_period_invalid if end_at < start_at
  end
end

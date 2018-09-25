class BotFeedbackDelegator < BaseDelegator
  validate :default_state?

  def initialize(record, options = {})
    @item = record
    super(record, options)
  end

  def default_state?
    errors[:id] << :invalid_bot_feedback_state unless @item.state == BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:default]
  end
end

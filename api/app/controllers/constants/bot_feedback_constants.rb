module BotFeedbackConstants
  LOAD_OBJECT_EXCEPT = %w[:index, :new].freeze
  VALIDATION_CLASS   = 'Bot::FeedbackValidation'.freeze
  DELEGATOR_CLASS    = 'BotFeedbackDelegator'.freeze
  INDEX_FIELDS       = %w(useful start_at end_at).freeze

  FEEDBACK_CATEGORY = [
    [:answered,   1], # answered
    [:unanswered, 2]  # unanswered
  ].freeze
  FEEDBACK_CATEGORY_KEYS_BY_TOKEN = Hash[*FEEDBACK_CATEGORY.map { |i| [i[0], i[1]] }.flatten].freeze
  FEEDBACK_CATEGORY_TOKEN_BY_KEY = Hash[*FEEDBACK_CATEGORY.map { |i| [i[1], i[0]] }.flatten].freeze

  FEEDBACK_USEFUL = [
    [:default,  1], # default
    [:yes,      2], # yes, useful
    [:no,       3]  # no, not useful
  ].freeze
  FEEDBACK_USEFUL_KEYS_BY_TOKEN = Hash[*FEEDBACK_USEFUL.map { |i| [i[0], i[1]] }.flatten].freeze
  FEEDBACK_USEFUL_TOKEN_BY_KEY = Hash[*FEEDBACK_USEFUL.map { |i| [i[1], i[0]] }.flatten].freeze

  FEEDBACK_STATE = [
    [:default,  1], # default
    [:mapped,   2], # article mapped to feedback
    [:deleted,  3]  # deleted feedback
  ].freeze
  FEEDBACK_STATE_KEYS_BY_TOKEN = Hash[*FEEDBACK_STATE.map { |i| [i[0], i[1]] }.flatten].freeze
  FEEDBACK_STATE_TOKEN_BY_KEY = Hash[*FEEDBACK_STATE.map { |i| [i[1], i[0]] }.flatten].freeze
end

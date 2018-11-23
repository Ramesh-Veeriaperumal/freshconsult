module BotFeedbackConstants
  LOAD_OBJECT_EXCEPT = [:index, :bulk_delete, :bulk_map_article, :create_article].freeze
  VALIDATION_CLASS   = 'Bot::FeedbackValidation'.freeze
  DELEGATOR_CLASS    = 'BotFeedbackDelegator'.freeze
  INDEX_FIELDS       = %w[useful start_at end_at].freeze
  BULK_MAP_ARTICLE_FIELDS = %w[article_id].freeze
  BULK_ACTION_METHODS = [:bulk_delete, :bulk_map_article, :create_article].freeze
  CREATE_ARTICLE_FIELDS = %w[title description folder_id].freeze
  CHAT_HISTORY_FIELDS = %w[query_id direction].freeze
  CHAT_HISTORY_DIRECTION_VALUES = {
    'frwrd': 'asc',
    'bkwrd': 'desc'
  }.with_indifferent_access.freeze
  CHAT_HISTORY_DIRECTIONS = CHAT_HISTORY_DIRECTION_VALUES.keys.freeze
  CHAT_HISTORY_MSG_COUNT = 10.freeze
  MSG_CONTENT_TYPES = {
    'artcl': {
      'response_key': 'suggested_articles',
      'url': 'url'
    },
    'itm': {
      'response_key': 'ticket',
      'url': 'btn2Url'
    }
  }.with_indifferent_access.freeze
  SKIP_BOT_LOAD = %w[chat_history].freeze

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

  # Category  Useful  Meaning
  #   1       1       ( suggested )
  #   1       2       ( answered )
  #   1       3       ( not possible )
  #   2       1       ( no articles were suggested )
  #   2       2       ( not possible )
  #   2       3       ( unanswered )

  FEEDBACK_STATE = [
    [:default,  1], # default
    [:mapped,   2], # article mapped to feedback
    [:deleted,  3]  # deleted feedback
  ].freeze
  FEEDBACK_STATE_KEYS_BY_TOKEN = Hash[*FEEDBACK_STATE.map { |i| [i[0], i[1]] }.flatten].freeze
  FEEDBACK_STATE_TOKEN_BY_KEY = Hash[*FEEDBACK_STATE.map { |i| [i[1], i[0]] }.flatten].freeze
end


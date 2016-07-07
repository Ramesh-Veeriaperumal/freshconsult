module SurveyConstants
  FIELDS = %w(feedback ratings).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(feedback).freeze

  CLASSIC_RATINGS = Survey::CUSTOMER_RATINGS.keys

  CUSTOM_RATINGS = CustomSurvey::Survey::CUSTOMER_RATINGS.keys

  INDEX_FIELDS = %w( user_id created_since).freeze #dont change the order since indexing depends on the order

  STATES = %w(active).freeze

  LOAD_OBJECT_EXCEPT = [:survey_results].freeze
end.freeze

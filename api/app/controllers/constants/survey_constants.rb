module SurveyConstants
  HASH_FIELDS = ['custom_ratings'].freeze

  FIELDS = %w(rating feedback).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(feedback).freeze

  CLASSIC_RATINGS = Survey::CUSTOMER_RATINGS.keys

  CUSTOM_RATINGS = CustomSurvey::Survey::CUSTOMER_RATINGS.keys

  INDEX_FIELDS = %w( user_id created_since).freeze #dont change the order since indexing depends on the order
end.freeze

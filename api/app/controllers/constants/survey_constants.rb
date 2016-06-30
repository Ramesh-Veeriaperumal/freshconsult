module SurveyConstants

  FIELDS = %w(feedback ratings).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(feedback).freeze

  CLASSIC_RATINGS = Survey::CUSTOMER_RATINGS.keys

  CUSTOM_RATINGS = CustomSurvey::Survey::CUSTOMER_RATINGS.keys

  INDEX_FIELDS = %w( created_since user_id).freeze
end.freeze

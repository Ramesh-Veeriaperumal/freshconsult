module FeatureConstants
  DISCUSSION = :forums
  TIME_ENTRIES = :timesheets
  PRODUCTS = :multi_product
  TICKETS = :compose_email
  SURVEYS = [:surveys].freeze
  SATISFACTION_RATINGS = [:surveys].freeze
  SATISFACTION_RATINGS_WITH_LINK = SATISFACTION_RATINGS | [:survey_links]
end

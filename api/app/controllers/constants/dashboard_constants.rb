module DashboardConstants
  INDEX_FIELDS = %w(since_id before_id page per_page).freeze
  LOAD_OBJECT_EXCEPT = [:index, :article_performance, :translation_summary].freeze
  DEFAULT_PAGE_LIMIT = 30
  MAX_PAGE_LIMIT = 100
  MIN_PAGE_LIMIT = 20
  ARTICLE_PERFORMANCE_FIELDS = %i[portal_id language].freeze
  TRANSLATION_SUMMARY_FIELDS = %i[portal_id].freeze
end.freeze

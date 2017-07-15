module DashboardConstants
  INDEX_FIELDS = %w(since_id before_id page per_page).freeze
  LOAD_OBJECT_EXCEPT = [:index].freeze
  DEFAULT_PAGE_LIMIT = 30
  MAX_PAGE_LIMIT = 100
  MIN_PAGE_LIMIT = 20
end.freeze

module Widget
  module Search
    module SolutionConstants
      DEFAULT_PAGE = 1
      MAX_PAGE = 10
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 30
      RESULTS_FIELDS = %i[page per_page language term solution].freeze
      VALIDATION_CLASS = 'Widget::Search::SolutionValidation'.freeze
    end
  end
end

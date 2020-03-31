module Ember::Dashboard
  class SolutionsController < ApiApplicationController
    include HelperConcern
    include SolutionConcern
    include Redis::Keys::Others
    include Redis::OthersRedis

    before_filter :validate_language, only: [:article_performance]
    before_filter :validate_dashboard_params, only: [:translation_summary, :article_performance]
    before_filter :dashboard_delegator_validation, only: [:translation_summary, :article_performance]

    FEATURE_REQUIREMENTS = {
      translation_summary: [:enable_multilingual]
    }.freeze

    def article_performance
      portal_filter = Solution::PortalLanguageFilter.new(params[:portal_id], @lang_id)
      query_result = portal_filter.articles.select('SUM(solution_articles.thumbs_up) as thumbs_up, SUM(solution_articles.thumbs_down) as thumbs_down, SUM(solution_articles.hits) as hits').first
      # we are using read_attribute(:hits) instead of hits, as we've override hits method to read redis value also.

      redis_keys = portal_filter.articles.pluck(:id).map do |id|
        format(SOLUTION_HIT_TRACKER, account_id: Account.current.id, article_id: id)
      end
      redis_hits = (get_multiple_others_redis_keys(redis_keys) || []).reduce(0) { |total, val| total + val.to_i }
      
      @article_performance_info = {
        hits: query_result.read_attribute(:hits).to_i + redis_hits,
        thumbs_up: query_result.read_attribute(:thumbs_up).to_i,
        thumbs_down: query_result.read_attribute(:thumbs_down).to_i
      }
      response.api_root_key = :article_performance
    end

    def translation_summary
      portal_filter = Solution::PortalLanguageFilter.new(params[:portal_id])
      query_result = portal_filter.all_article_translations.group('solution_articles.language_id').count
      @translation_summary = Hash[Account.current.all_language_objects.map { |language| [language.code, query_result[language.id].to_i]}]
      response.api_root_key = :translation_summary
    end

    private

      def validate_dashboard_params
        @validation_klass = 'SolutionDashboardValidation'
        validate_query_params
      end

      def dashboard_delegator_validation
        @delegator_klass = 'SolutionDashboardDelegator'
        return unless validate_delegator(nil, portal_id: params[:portal_id])
      end

      def constants_class
        :DashboardConstants.to_s.freeze
      end

      def feature_name
        FEATURE_REQUIREMENTS[action.to_sym]
      end
  end
end

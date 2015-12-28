# encoding: utf-8
class Support::SearchV2::SolutionsController < Support::SearchV2::SpotlightController

  attr_accessor :related_articles, :container

  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_spotlight_models = {
    'article' => { model: 'Solution::Article',  associations: [ :folder, :article_body ] }
  }

  def related_articles
    @no_render          = true
    @size               = params[:limit]
    @search_context     = :portal_related_articles
    search
    @related_articles   = @result_set
    @container          = params[:container]

    render template: '/support/search/related_articles', :layout => false
  end

  private

    # Constructing params for ES
    #
    def construct_es_params
      Hash.new.tap do |es_params|
        es_params[:search_term] = ("#{@article.tags.map(&:name).join(' ')} #{@article.title}").gsub(/[\^\$]/, '')
        return [] if es_params[:search_term].blank?

        es_params[:language_id]               = Language.for_current_account.id
        es_params[:article_id]                = @article.id
        es_params[:article_status]            = Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft]
        es_params[:article_visibility]        = @article.user_visibility
        es_params[:article_company_id]        = User.current.company_id
        es_params[:article_category_id]       = current_portal.portal_solution_categories.map(&:solution_category_id)

        es_params[:size]                      = @size
        es_params[:from]                      = @offset
      end.merge(ES_BOOST_VALUES[@search_context])
    end

    def initialize_search_parameters
      super
      @searchable_klasses = ['Solution::Article']
      @article            = current_account.solution_articles.find(params[:article_id])
      @no_render          = true
    end

end

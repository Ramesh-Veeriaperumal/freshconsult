# encoding: utf-8
class Support::SearchV2::SolutionsController < SupportController

  include Search::V2::AbstractController

  def related_articles
    search(esv2_portal_models) do |results|
      @related_articles = results
    end

    render template: '/support/search/related_articles', :layout => false
  end

  private

    # Constructing params for ES
    #
    def construct_es_params
      super.tap do |es_params|
        es_params[:search_term] = ("#{@article.tags.map(&:name).join(' ')} #{@article.title}").gsub(/[\^\$]/, '')
        return [] if es_params[:search_term].blank?

        es_params[:language_id]         = Language.current.try(:id) || Language.for_current_account.id
        es_params[:article_id]          = @article.id
        es_params[:article_status]      = Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft]
        es_params[:article_visibility]  = @article.user_visibility
        es_params[:article_company_id]  = User.current.try(:company_id)
        es_params[:article_category_id] = current_portal.portal_solution_categories.map(&:solution_category_meta_id)

        es_params[:size]                = @size
        es_params[:from]                = @offset
      end.merge(ES_V2_BOOST_VALUES[@search_context])
    end

    def initialize_search_parameters
      super
      @klasses        = ['Solution::Article']
      @article        = current_account.solution_articles.find(params[:article_id])
      @no_render      = true
      @container      = params[:container]
      @search_context = :portal_related_articles
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_portal_models
      @@esv2_portal_solution ||= {
        'article' => { model: 'Solution::Article',  associations: [ :folder, :article_body ] }
      }
    end

end

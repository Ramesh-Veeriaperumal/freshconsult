class Support::BotResponsesController < SupportController
  before_filter :bot_email_feature_enabled?
  before_filter :validate_params
  before_filter :load_params
  before_filter :load_item
  before_filter :load_usefulness, only: :filter
  before_filter :check_for_positive_feedback, only: :update_response

  def update_response 
    @item.assign_useful(@solution_id, @useful)
    @item.save
    render :json => construct_json_response
  end

  def filter
    assigned = @item.assign_opened(@solution_id, true)
    @item.save if assigned
    render :json => construct_json_response
  end

  private

    def load_usefulness
      @useful = @item.useful?(@solution_id)
    end

    def construct_json_response
      response = {
        ticket_closed: @item.ticket.closed?,
        positive_feedback: @item.has_positive_feedback?
      }
      unless @useful.nil?
        response[:useful] = @useful
        response.merge!(construct_other_articles) unless @useful
      end
      response
    end

    def construct_other_articles
      other_articles = @item.solutions_without_feedback.each.map do |article_meta_id|
        article = @current_account.solution_article_meta.find(article_meta_id)
        { 
          url: article_url(article),
          title: article.title
        }
      end
      other_articles.present? ? { other_articles: other_articles } : {}
    end

    def scoper
      current_account.bot_responses
    end

    def article_url article
      support_solutions_article_url(article, host: @current_portal.host)
    end

    def load_item
      @item = scoper.find_by_query_id(params[:query_id])
      solution = @item.suggested_articles[@solution_id] if @item
      render_404 if @item.blank? || solution.blank?
    end

    def check_for_positive_feedback
      render_request_error :positive_feedback_available, 403 if @item.has_positive_feedback? 
    end

    def validate_params
      render_request_error :missing_params, 400 if required_params_missing?
    end

    def required_params_missing?
      params[:solution_id].blank? || params[:query_id].blank? || (action == :update_response && params[:useful].to_s.blank?)
    end

    def load_params
      @solution_id = params[:solution_id].to_i
      @useful = params[:useful].to_s.to_bool
    end

    def bot_email_feature_enabled?
      render_request_error(:require_feature, 403, feature: 'bot_email_channel') unless current_account.bot_email_channel_enabled?
    end
end

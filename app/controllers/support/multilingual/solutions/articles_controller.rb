class Support::Multilingual::Solutions::ArticlesController < Support::Solutions::ArticlesController
  
  def hit
    @article.current_article.hit! unless agent?
    render_tracker
  end

  private
    def load_and_check_permission
      @article = current_account.solution_article_meta.find(params[:id])
      unless @article.visible?(current_user)
        unless logged_in?
          session[:return_to] = solution_category_folder_article_path(
              @article.solution_folder_meta.solution_category_meta_id,
              @article.solution_folder_meta_id, @article.id)
          redirect_to login_url
        else
          flash[:warning] = t(:'flash.general.access_denied')
          redirect_to support_solutions_path and return
        end
      end
    end
    
    def article_visible?
      return false unless (((current_user && current_user.agent? && privilege?(:view_solutions)) || @article.current_article.published?) and @article.visible_in?(current_portal))
      draft_preview_agent_filter?
    end
    
    def draft_preview_agent_filter?
      return (current_user && current_user.agent? && (@article.draft.present? || !@article.current_article.published?) && privilege?(:view_solutions)) if draft_preview?
      true
    end
end

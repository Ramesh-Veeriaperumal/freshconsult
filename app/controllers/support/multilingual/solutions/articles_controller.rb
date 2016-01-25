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
end

class Mobihelp::Multilingual::ArticlesController < Mobihelp::ArticlesController

  private

    def load_article
      @article = current_account.solution_article_meta.find_by_id(params[:id])
    end
end

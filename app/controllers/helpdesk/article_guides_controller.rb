class Helpdesk::ArticleGuidesController < ApplicationController
  layout 'helpdesk/default'

  before_filter { |c| c.requires_permission :manage_knowledgebase }

  def create

    if params[:article_id]
      article = Helpdesk::Article.find_by_id(params[:article_id])
      @articles = article ? [article] : []
    else
      @articles = params[:ids].map { |id| Helpdesk::Article.find_by_id(id) }
    end

    guide = Helpdesk::Guide.find_by_id(params[:guide_id])

    raise ActiveRecord::RecordNotFound if !guide || @articles.empty? 

    @articles.each do |a| 
      begin
        a.guides << guide 
      rescue ActiveRecord::RecordInvalid => e
      end
    end


    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@articles.length, 'article was', 'articles were') %> assigned to #{guide.name}")

    redirect_to :back
    
  end

  
end

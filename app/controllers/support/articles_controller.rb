class Support::ArticlesController < ApplicationController
  layout 'ssportal'

  before_filter { |c| c.requires_permission :portal_knowledgebase }

  def index
    @articles = Helpdesk::Article.visible(current_account).paginate(
      :page => params[:page], 
      :conditions => ["title LIKE ?", "%#{params[:v]}%"],
      :per_page => 10
    )
  end
  
  def show
    @article = Helpdesk::Article.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @article && (@article.account_id == current_account.id)
  end
  

end

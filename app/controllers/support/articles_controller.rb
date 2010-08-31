class Support::ArticlesController < ApplicationController
  layout 'support/default'

  before_filter { |c| c.requires_permission :portal_knowledgebase }

  def index
    @articles = Helpdesk::Article.visible.paginate(
      :page => params[:page], 
      :conditions => ["title LIKE ?", "%#{params[:v]}%"],
      :per_page => 10
    )
  end

end

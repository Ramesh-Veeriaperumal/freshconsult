class ForumCategoriesController < ApplicationController
  include ModelControllerMethods
  
  def index
     @forum_categories = scoper.all
  end
  
  def show
    
    @forum_category = ForumCategory.find(params[:id])
    @forums = @forum_category.forums.paginate :page => params[:page]

    respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_category }
    end
  end
    
  protected
    def scoper
      current_account.forum_categories
    end
    
end

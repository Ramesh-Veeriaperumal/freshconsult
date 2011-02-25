class ForumCategoriesController < ApplicationController
  include ModelControllerMethods
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_forums
  end
  
  before_filter :set_selected_tab
  
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
    
    def set_selected_tab
      @selected_tab = 'Forums'
    end
    
end

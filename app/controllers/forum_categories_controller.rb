class ForumCategoriesController < ApplicationController
  include ModelControllerMethods
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_forums
  end
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :set_selected_tab
  before_filter :content_scope
  
  def index
     @forum_categories = scoper.all
     respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_categories }
      format.json  { render :json => @forum_categories }
      format.atom 
    end
  end
  
  def show
    
    @forum_category = scoper.find(params[:id])
    @forums = @forum_category.forums.paginate :page => params[:page]

    respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_category.to_xml(:include => :forums) }
      format.json  { render :json => @forum_category.to_json(:include => :forums) }
      format.atom 
      
     
    end
  end
  
  def destroy
    @result = @obj.destroy
    respond_to do |wants|
      wants.html do
        if @result
          flash[:notice] = t(:'flash.general.destroy.success', :human_name => human_name)
          redirect_to categories_path
        else
          render :action => 'show'
        end
    end
  end
  end
    
  protected
  
    def content_scope
      @content_scope = 'portal_' 
      @content_scope = 'user_'  if permission?(:post_in_forums) 
      @content_scope = ''  if permission?(:manage_forums)
    end
    
    def scoper
      current_account.forum_categories
    end
    
    def set_selected_tab
      @selected_tab = 'Forums'
    end
    
end

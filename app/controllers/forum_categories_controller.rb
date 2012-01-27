class ForumCategoriesController < ApplicationController
  include ModelControllerMethods
  include Helpdesk::ReorderUtility
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_forums
  end
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :portal_category?, :except => :index
  before_filter :set_selected_tab
  before_filter :content_scope
  
  def index
     @forum_categories = current_portal.forum_categories
     respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_categories }
      format.json  { render :json => @forum_categories }
      format.atom 
    end
  end
  
  def create
    if @obj.save
      flash[:notice] = create_flash
      respond_to do |format|
      format.html { redirect_back_or_default redirect_url }
      format.xml { render :xml => @obj, :status => :created, :location => category_url(@obj) }
    end
    else
      create_error
      respond_to do |format|
        format.html  { render :action => 'new' }
        format.xml { render :xml => @obj.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def show
    
    @forum_category = scoper.find(params[:id])
    @forums = @forum_category.forums.paginate :page => params[:page]

    respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_category.to_xml(:include => fetch_forum_scope) }
      format.json  { render :json => @forum_category.to_json(
                              :except => [:account_id,:import_id],
                              :include => fetch_forum_scope) }
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
    
    def reorder_scoper
      scoper
    end
    
    def reorder_redirect_url
      categories_path
    end
    
    def portal_category?
      wrong_portal unless(main_portal? || 
            (params[:id] && params[:id].to_i == current_portal.forum_category_id))
    end
    
    def set_selected_tab
      @selected_tab = :forums
    end
    
    def fetch_forum_scope
      if current_user && current_user.has_manage_forums?
      :forums
     elsif current_user
      :user_forums
     else
      :portal_forums 
     end
    end
    
end

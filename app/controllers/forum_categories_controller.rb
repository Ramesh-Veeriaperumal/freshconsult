class ForumCategoriesController < ApplicationController
  include ModelControllerMethods
  include Helpdesk::ReorderUtility
  
  rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :portal_category?, :except => :index
  before_filter :set_selected_tab
  before_filter :content_scope
  
  def index
    @forum_categories = current_portal.forum_categories
    respond_to do |format|
      format.html { @page_canonical = categories_url }
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
      format.html { @page_canonical = category_url(@forum_category) }
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
      wants.xml { render :xml =>@result}
      wants.json { render :json =>@result}
    end
  end  
    
  protected
  
    def content_scope
      @content_scope = ''
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
      :forums
    end

    def RecordNotFoundHandler
      flash[:notice] = I18n.t(:'flash.forum_category.page_not_found')
      redirect_to categories_path
    end

end

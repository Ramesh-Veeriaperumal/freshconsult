class Solution::CategoriesController < ApplicationController
  
  include Helpdesk::ReorderUtility
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_knowledgebase
  end
  
  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :portal_category?, :except => :index
  before_filter :set_selected_tab     
  before_filter :page_title  
  
  def index
    
    @categories = permission?(:manage_knowledgebase) ? current_portal.solution_categories : 
      (main_portal? ? current_portal.solution_categories.customer_categories : current_portal.solution_categories)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @categories }
      format.json  { render :json => @categories }
    end
  end

  def show
    
     @item = current_account.solution_categories.find(params[:id], :include => :folders)
    
     respond_to do |format|
      if (@item.is_default? && !permission?(:manage_knowledgebase))
        store_location
        format.html {redirect_to login_url }
      else
        format.html # index.html.erb
      end
      format.xml {  render :xml => @item.to_xml(:include => fetch_folder_scope) }
      format.json  { render :json => @item.to_json(:except => [:account_id,:import_id],
                                                    :include => fetch_folder_scope) }
    end
     
  end
  
  def new
    @category = current_account.solution_categories.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @category }
    end
  end

  def edit
    
     @category = current_account.solution_categories.find(params[:id])      
      respond_to do |format|
      if @category.is_default?
        flash[:notice] = I18n.t('category_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
        format.html # edit.html.erb
      end
      format.xml  { render :xml => @category }
    end
  end

  def create
    
     @category = current_account.solution_categories.new(params[nscname]) 
     
    redirect_to_url = solution_categories_url
    redirect_to_url = new_solution_category_path unless params[:save_and_create].nil?
    
    respond_to do |format|
      if @category.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @category, :status => :created, :location => @category }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def update
    
     @category = current_account.solution_categories.find(params[:id]) 
    
    respond_to do |format|
     
       if @category.update_attributes(params[nscname])       
          format.html { redirect_to :action =>"index" }
          format.xml  { render :xml => @category, :status => :created, :location => @category }     
       else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
       end
    end
  end

  def destroy
    
    @category = current_account.solution_categories.find(params[:id])
    @category.destroy unless @category.is_default?

    respond_to do |format|
      format.html {  redirect_to :action =>"index" }
      format.xml  { head :ok }
    end
end

 protected

  def scoper
    eval "Solution::#{cname.classify}"
  end                                     
  
  def page_title
    @page_title = t("header.tabs.solutions") 
  end
  
  def reorder_scoper
    current_account.solution_categories
  end
  
  def reorder_redirect_url
    solution_categories_path
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def set_selected_tab
      @selected_tab = :solutions
  end
  
  def portal_category?
    wrong_portal unless(main_portal? || 
          (params[:id] && params[:id].to_i == current_portal.solution_category_id))
  end
  
  def fetch_folder_scope
    if current_user && current_user.has_manage_solutions?
      :folders
    elsif current_user
      :user_folders
    else
      :public_folders 
    end
  end

end

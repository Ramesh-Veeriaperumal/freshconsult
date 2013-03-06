class Solution::FoldersController < ApplicationController
  include Helpdesk::ReorderUtility

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :portal_category?
  before_filter :set_selected_tab       
  before_filter :page_title
  
  
  def index        
    current_category  = current_account.solution_categories.find(params[:category_id])
    @folders = current_category.folders.all   

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @folders }
      format.json  { render :json => @folders }
    end
  end

  def show    
    current_category = current_account.solution_categories.find(params[:category_id])
    @item = current_category.folders.find(params[:id], :include => :articles)
    
    respond_to do |format|
      format.html { @page_canonical = solution_category_folder_url(current_category, @item) }
      format.xml  { render :xml => @item.to_xml(:include => articles_scope) }
      format.json { render :json => @item.to_json(:except => [:account_id,:import_id],:include => articles_scope) }
    end
  end
  

  def new    
    current_category = current_account.solution_categories.find(params[:category_id])
    @folder = current_category.folders.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @folder }
    end
  end

  def edit
    current_category = current_account.solution_categories.find(params[:category_id])
    @folder = current_category.folders.find(params[:id])      
    respond_to do |format|
      if @folder.is_default?
        flash[:notice] = I18n.t('folder_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
         format.html # edit.html.erb
      end
      format.xml  { render :xml => @folder }
    end
  end

  def create 
    current_category = current_account.solution_categories.find(params[:category_id])    
    @folder = current_category.folders.new(params[nscname]) 
    @folder.category_id = params[:category_id]

    redirect_to_url = solution_category_url(params[:category_id])
    redirect_to_url = new_solution_category_folder_path(params[:category_id]) unless
      params[:save_and_create].nil?
   
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @folder.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @folder, :status => :created }
        format.json  { render :json => @folder, :status => :created }     
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def update
    current_category = current_account.solution_categories.find(params[:category_id])     
    @folder = current_category.folders.find(params[:id])
    
    redirect_to_url = solution_category_url(params[:category_id])
    
    respond_to do |format|     
      if @folder.update_attributes(params[nscname])       
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @folder, :status => :success } 
        format.json  { render :json => @folder, :status => :success }     
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    current_category = current_account.solution_categories.find(params[:category_id])     
    @folder = current_category.folders.find(params[:id])
    
    @folder.destroy unless @folder.is_default?
    
    redirect_to_url = solution_category_url(params[:category_id])
    
    respond_to do |format|
      format.html { redirect_to redirect_to_url }
      format.xml  { head :ok }
      format.json  { head :ok }
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
    current_account.solution_categories.find(params[:category_id]).folders
  end
  
  def reorder_redirect_url
    solution_category_url(params[:category_id])
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
          (params[:category_id].to_i == current_portal.solution_category_id)) #Duplicate..
  end
  
  def articles_scope
    :articles
  end

end

class Solution::FoldersController < ApplicationController
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_knowledgebase
  end
  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :check_folder_permission, :only => [:show]
  before_filter :set_selected_tab
  
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
      format.html 
      format.xml  { render :xml => @item.to_xml(:include => :articles) }
      format.json  { render :json => @item.to_json(:include => :articles) }
    end
    
  end

  def new    
     logger.debug "params:: #{params.inspect}"
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
      format.html # edit.html.erb
      format.xml  { render :xml => @folder }
    end
  end

  def create 
    
    current_category = current_account.solution_categories.find(params[:category_id])    
    @folder = current_category.folders.new(params[nscname]) 
    @folder.category_id = params[:category_id]
    redirect_to_url = solution_category_url(params[:category_id])
    redirect_to_url = new_solution_category_folder_path(params[:category_id]) unless params[:save_and_create].nil?
   
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @folder.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @folder, :status => :created, :location => @folder }
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
          format.xml  { render :xml => @folder, :status => :created, :location => @folder }     
       else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
       end
    end
  end

  def destroy
    
    current_category = current_account.solution_categories.find(params[:category_id])     
    @folder = current_category.folders.find(params[:id])
    
    @folder.destroy
    
    redirect_to_url = solution_category_url(params[:category_id])
    
    respond_to do |format|
      format.html { redirect_to redirect_to_url }
      format.xml  { head :ok }
    end
    
  end


 protected

  def scoper
    eval "Solution::#{cname.classify}"
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def set_selected_tab
      @selected_tab = 'Solutions'
  end
  
  def check_folder_permission
    current_category = current_account.solution_categories.find(params[:category_id])
    @folder = current_category.folders.find(params[:id], :include => :articles)    
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) if !@folder.nil? and  !@folder.visible?(current_user)
  end

end

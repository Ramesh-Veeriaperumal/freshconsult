class Solution::CategoriesController < ApplicationController
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_knowledgebase
  end
  
  before_filter :set_selected_tab
  
  def index
    
    @categories = current_account.solution_categories.all    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @categories }
      format.json  { render :json => @categories }
    end
  end

  def show
    
     @item = current_account.solution_categories.find(params[:id], :include => :folders)
     
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item.to_xml(:include => :folders) }
      format.json  { render :json => @item.to_json(:include => :folders) }
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
      format.html # edit.html.erb
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
    @category.destroy

    respond_to do |format|
      format.html {  redirect_to :action =>"index" }
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

end

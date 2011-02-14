class Solution::CategoriesController < ApplicationController
  
  before_filter :set_selected_tab
  def index
    
     @categories = current_account.solution_categories.all
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @categories }
    end
  end

  def show
    
     @item = Solution::Category.find(params[:id], :include => :folders)
     
  end

  def new
    @category = current_account.solution_categories.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @category }
    end
  end

  def edit
  end

  def create
    
     @category = current_account.solution_categories.new(params[nscname]) 
    respond_to do |format|
      if @category.save
        format.html { redirect_to :action =>"index" }
        format.xml  { render :xml => @category, :status => :created, :location => @category }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def update
  end

  def destroy
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

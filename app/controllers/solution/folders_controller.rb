class Solution::FoldersController < ApplicationController
  before_filter :set_selected_tab
  def index    
    @folders = Solution::Folder.all
    print @folders

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @folders }
    end
    
  end

  def show    
    @item = Solution::Folder.find(params[:id], :include => :articles)
    
  end

  def new
    
      logger.debug "params:: #{params.inspect}"
      current_category = Solution::Category.find(params[:category_id])
     @folder = current_category.folders.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @folder }
    end
  end

  def edit
  end

  def create 
    
    logger.debug "params:: #{params.inspect}"
    @folder = Solution::Folder.new(params[nscname]) 
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @folder.save
        format.html { redirect_to :action =>"index" }
        format.xml  { render :xml => @folder, :status => :created, :location => @folder }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
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

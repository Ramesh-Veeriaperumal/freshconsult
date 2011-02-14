class Solution::ArticlesController < ApplicationController
  
  before_filter :set_selected_tab
  
  def index
    @articles = Solution::Article.all
    
    @articles = @articles.paginate( 
      :page => params[:page], 
      :order => Helpdesk::Article::SORT_SQL_BY_KEY[(params[:sort] || :created_desc).to_sym],
      :per_page => 20)
  end

  def show
    
    logger.debug "show is :: #{params.inspect}"
     @article = Solution::Article.find(params[:id])
    
  end

  def new
     logger.debug "params:: #{params.inspect}"
     current_folder = Solution::Folder.first
     current_folder = Solution::Folder.find(params[:folder_id]) unless params[:folder_id].nil?
     @article = current_folder.articles.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @article }
    end
  end

  def edit
    
    @article = Solution::Article.find(params[:id])      
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @article }
    end
    
  end

  def create
    
    @article = Solution::Article.new(params[nscname]) 
    set_item_user
    logger.debug "@article is :: #{@article.inspect}"
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @article.save
        format.html { redirect_to :action =>"index" }
        format.xml  { render :xml => @article, :status => :created, :location => @article }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
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
  
  def set_item_user
    
    @article.user ||= current_user if (@article.respond_to?('user=') && !@article.user_id)
    
  end
  
  def set_selected_tab
      @selected_tab = 'Solutions'
  end

end

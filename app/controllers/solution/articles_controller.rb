class Solution::ArticlesController < ApplicationController
  
  before_filter :set_selected_tab
  uses_tiny_mce :options => Helpdesk::EDITOR_OPTIONS 
  def index
    @articles = current_account.solution_articles.all
    
    @articles = @articles.paginate( 
      :page => params[:page], 
      :order => Helpdesk::Article::SORT_SQL_BY_KEY[(params[:sort] || :created_desc).to_sym],
      :per_page => 20)
  end

  def show
    
    logger.debug "show is :: #{params.inspect}"
     @article = Solution::Article.find(params[:id], :include => :folder) 
    
  end

  def new
     logger.debug "params:: #{params.inspect}"
     current_folder = Solution::Folder.first
     current_folder = Solution::Folder.find(params[:folder_id]) unless params[:folder_id].nil?
     @article = current_folder.articles.new
     @article.is_public = "true"
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
  
   current_folder = Solution::Folder.find(params[:folder_id]) 
   @article = current_folder.articles.new(params[nscname]) 
    set_item_user
   
    redirect_to_url = solution_category_folder_url(params[:category_id], params[:folder_id])
    redirect_to_url = new_solution_category_folder_article_path(params[:category_id], params[:folder_id]) unless params[:save_and_create].nil?
   
    respond_to do |format|
      if @article.save
        #create_attachments Need to handle this case
        format.html { redirect_to redirect_to_url }        
        format.xml  { render :xml => @article, :status => :created, :location => @article }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def save_and_create
    
    logger debug "Inside save and create"
    
  end

  def update
    
    redirect_to_url = solution_category_folder_url(params[:category_id], params[:folder_id])
    
    logger.debug "Inside update :: #{params.inspect}"
    @article = Solution::Article.find(params[:id]) 
    
    redirect_to_url = solution_category_folder_url(params[:category_id], params[:folder_id])   
    
    respond_to do |format|
     
       if @article.update_attributes(params[nscname])       
          format.html { redirect_to redirect_to_url }
          format.xml  { render :xml => @article, :status => :created, :location => @article }     
       else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
       end
    end
  end

  def destroy
    logger.debug "params::: #{params.inspect}"
    @article = Solution::Article.find(params[:id])
    @article.destroy
    
    respond_to do |format|
      format.html { redirect_to(solution_category_folder_url(params[:category_id],params[:folder_id])) }
      format.xml  { head :ok }
    end
    
  end

 def create_attachments
    return unless @article.respond_to?(:attachments)
    (params[nscname][:attachments] || []).each do |a|
      @article.attachments.create(:content => a[:file], :description => a[:description], :account_id => @article.account_id)
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
  
  def set_item_user
    
    @article.user ||= current_user if (@article.respond_to?('user=') && !@article.user_id)
    
    @article.account_id ||= current_account.id if (@article.respond_to?('account_id='))
    
  end
  
  def set_selected_tab
      @selected_tab = 'Solutions'
  end

end

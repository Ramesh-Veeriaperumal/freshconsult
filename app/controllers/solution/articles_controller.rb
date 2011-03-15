class Solution::ArticlesController < ApplicationController
  
  before_filter :check_user , :only => [:show]
  before_filter :set_selected_tab
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_knowledgebase
  end
  
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
      if @article.save!
        post_persist 
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
          post_persist
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
  
   def delete_tag
     
     logger.debug "delete_tag :: params are :: #{params.inspect} "
     
     article = Solution::Article.find(params[:article_id])
     
     tag = article.tags.find_by_id(params[:tag_id])
      
     raise ActiveRecord::RecordNotFound unless tag

    Helpdesk::TagUse.find_by_article_id_and_tag_id(article.id, tag.id).destroy

    flash[:notice] = "The tag was removed from this Solution"
    redirect_to :back

      
  end

def post_persist
  
  create_attachments
  set_solution_tags
  
end
 def create_attachments
   logger.debug "create_attachments  "
    return unless @article.respond_to?(:attachments)
    (params[nscname][:attachments] || []).each do |a|
      logger.debug "creating file :#{a[:file]}"
      @article.attachments.create(:content => a[:file], :description => a[:description], :account_id => @article.account_id)
    end
  end
  
   def check_user
    if current_user.nil? || current_user.customer?
      @article = Solution::Article.find(params[:id], :include => :folder)
      return redirect_to(support_article_url(@article)) 
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
    
    @article.account ||= current_account
    
  end
  
  def set_selected_tab
      @selected_tab = 'Solutions'
  end

  def set_solution_tags
    
    tags = params[:tags][:name]
    ar_tags =  tags.scan(/\w+/)    
    new_tag = nil
    ar_tags.each do |tag|    
      
      new_tag = Helpdesk::Tag.find_by_name_and_account_id(tag, current_account) || Helpdesk::Tag.new(:name => tag ,:account_id => current_account.id)

       begin
        @article.tags << new_tag
        rescue ActiveRecord::RecordInvalid => e
      end
      
    end   
    
  end
end

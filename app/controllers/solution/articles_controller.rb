class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  
  before_filter :set_selected_tab
  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  
  
  def index    
    redirect_to_url = solution_category_folder_url(params[:category_id], params[:folder_id])    
    redirect_to redirect_to_url    
  end

  def show           
    @article = current_account.solution_articles.find(params[:id], :include => :folder) 
    wrong_portal and return unless(main_portal? || 
      (@article.folder.category_id == current_portal.solution_category_id))
    @page_title = @article.article_title
    @page_description = @article.article_description
    @page_keywords = @article.article_keywords
        
    respond_to do |format|
      format.html { @page_canonical = solution_category_folder_article_url(@article.folder.category, @article.folder.id, @article) }
      format.xml  { render :xml => @article.to_xml(:include => :folder) }
      format.json { render :json => @article.to_json(:include => {:folder => {:except => [:is_default]}}) }
    end    
  end

  def new
    current_folder = Solution::Folder.first
    current_folder = Solution::Folder.find(params[:folder_id]) unless params[:folder_id].nil?
    @article = current_folder.articles.new    
    @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @article }
    end
  end

  def edit
    @article = current_account.solution_articles.find(params[:id])      
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @article }
    end
  end

  def create
    current_folder = Solution::Folder.find(params[:solution_article][:folder_id]) 
    @article = current_folder.articles.new(params[nscname]) 
    set_item_user 

    redirect_to_url = @article
    redirect_to_url = new_solution_category_folder_article_path(params[:category_id], params[:folder_id]) unless params[:save_and_create].nil?
    build_attachments
    set_solution_tags
    respond_to do |format|
      if @article.save
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
    @article = current_account.solution_articles.find(params[:id]) 
    build_attachments
    set_solution_tags    
    respond_to do |format|    
      if @article.update_attributes(params[nscname])  
        format.html { redirect_to @article }
        format.xml  { render :xml => @article, :status => :created, :location => @article }     
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @article = current_account.solution_articles.find(params[:id])
    @article.destroy
    
    respond_to do |format|
      format.html { redirect_to(solution_category_folder_url(params[:category_id],params[:folder_id])) }
      format.xml  { head :ok }
    end
  end
   
  def delete_tag  
    logger.debug "delete_tag :: params are :: #{params.inspect} "     
    article = current_account.solution_articles.find(params[:article_id])     
    tag = article.tags.find_by_id(params[:tag_id])      
    raise ActiveRecord::RecordNotFound unless tag
    Helpdesk::TagUse.find_by_article_id_and_tag_id(article.id, tag.id).destroy
    flash[:notice] = t(:'flash.solutions.remove_tag.success')
    redirect_to :back 
  end
  
  protected

    def scoper
      eval "Solution::#{cname.classify}"
    end

    def build_attachments
      return unless @article.respond_to?(:attachments)
      (params[nscname][:attachments] || []).each do |a|
        @article.attachments.build(:content => a[:resource], :description => a[:description], :account_id => @article.account_id)
      end
    end
    
    def reorder_scoper
      current_account.solution_articles.find(:all, :conditions => {:folder_id => params[:folder_id] })
    end
    
    def reorder_redirect_url
      solution_category_folder_url(params[:category_id], params[:folder_id])
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
      @selected_tab = :solutions
    end     
    
    def page_title
      @page_title = t("header.tabs.solutions")    
    end

    def set_solution_tags      
      @article.tags.clear    
      tags = params[:tags][:name]
      ar_tags =  tags.scan(/\w+/)    
      new_tag = nil

      ar_tags.each do |tag|      
        new_tag = Helpdesk::Tag.find_by_name_and_account_id(tag, current_account) ||
           Helpdesk::Tag.new(:name => tag ,:account_id => current_account.id)
        begin
          @article.tags << new_tag
        rescue ActiveRecord::RecordInvalid => e
        end

      end   
    end
   
end

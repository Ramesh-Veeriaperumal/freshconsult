# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_article, :only => [:edit, :update, :destroy, :reset_ratings]
  before_filter :feature_enabled?, :only => [:edit, :update, :show, :create]
  

  def index
    redirect_to solution_category_folder_url(params[:category_id], params[:folder_id])
  end

  def show
    @enable_pattern = true
    @article = current_account.solution_articles.find_by_id!(params[:id], :include => [:folder, :draft])
    respond_to do |format|
      format.html
      format.xml  { render :xml => @article }
      format.json { render :json => @article }
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
    @feature ? load_draft :
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
    set_solution_tags(@artcile)
    respond_to do |format|
      if @article.save
        (forge_draft unless save_and_publish?) if @feature
        format.html { redirect_to redirect_to_url }        
        format.xml  { render :xml => @article, :status => :created, :location => @article }
        format.json  { render :json => @article, :status => :created, :location => @article }
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
    @feature ? update_draft :  update_article
  end

  def destroy
    @article.destroy
    
    respond_to do |format|
      format.html { redirect_to(solution_category_folder_url(params[:category_id],params[:folder_id])) }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end
   

   def delete_tag  #possible dead code
     logger.debug "delete_tag :: params are :: #{params.inspect} "     
     article = current_account.solution_articles.find(params[:article_id])     
     tag = article.tags.find_by_id(params[:tag_id])      
     raise ActiveRecord::RecordNotFound unless tag
     Helpdesk::TagUse.find_by_article_id_and_tag_id(article.id, tag.id).destroy
    flash[:notice] = t(:'flash.solutions.remove_tag.success')
    redirect_to :back    
   end

  def reset_ratings
    @article.update_attributes(:thumbs_up => 0, :thumbs_down => 0 )
    @article.votes.destroy_all
  
    respond_to do |format|
      format.js
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  protected

    def load_article
      @article = current_account.solution_articles.find(params[:id])
    end

    def scoper #possible dead code
      eval "Solution::#{cname.classify}"
    end

    def build_attachments
      attachment_builder(@article, params[nscname][:attachments], params[:cloud_file_attachments] )
    end
    
    def reorder_scoper
      current_account.solution_articles.find(:all, :conditions => {:folder_id => params[:folder_id] })
    end
    
    def reorder_redirect_url
      solution_category_folder_url(params[:category_id], params[:folder_id])
    end

    def cname #possible dead code
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

    def set_solution_tags(obj)
      return unless params[:tags] && (params[:tags].is_a?(Hash) && params[:tags][:name].present?)      
      @article.tags.clear    
      tags = params[:tags][:name]
      ar_tags = tags.split(',').map(&:strip).uniq    
      new_tag = nil

      ar_tags.each do |tag|      
        new_tag = Helpdesk::Tag.find_by_name_and_account_id(tag, current_account) ||
           Helpdesk::Tag.new(:name => tag ,:account_id => current_account.id)
        begin
          obj.tags << new_tag
        rescue ActiveRecord::RecordInvalid => e
        end

      end   
    end
    
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to support_solutions_article_path(params[:id])
      elsif !privilege?(:view_solutions)
        access_denied
      end
    end

    def feature_enabled?
      @feature = true
    end

    def save_and_publish?
      params[:save_and_publish].present?
    end

    def forge_draft
      @draft = @article.build_draft
    end

    def load_draft
      @draft = current_account.solution_drafts.find_by_article_id(params[:id])
      ((@draft = @article.build_draft) and return) unless @draft.present?
      unless @draft.lock_for_editing!
        flash[:error] = "This artcile is edited upon by somebody else. You can't edit simultaneously."
        redirect_to :action => "show" and return
      end
    end

    def update_draft
      @draft = current_account.solution_drafts.find_by_article_id(params[:id])
      if (@draft.present? && (@draft.current_author == current_user) && update_draft_attributes)
        flash[:success], action = "This article draft was saved succesfully.", "show"
      end
      flash ||= {:error => "This article draft could not be saved."}
      redirect_to :action => (action || "edit") and return
    end

    def update_draft_attributes
      attachment_builder(@draft, params[:solution_article][:attachments], params[:cloud_file_attachments])
      set_solution_tags(@draft)
      @draft.unlock
      @draft.update_attributes(params[:article])
    end

    def update_article
      build_attachments
      set_solution_tags(@article)    
      respond_to do |format|    
        if @article.update_attributes(params[nscname])  
          format.html { redirect_to @article }
          format.xml  { render :xml => @article, :status => :created, :location => @article }     
          format.json  { render :json => @article, :status => :ok, :location => @article }    
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
        end
      end
    end

end

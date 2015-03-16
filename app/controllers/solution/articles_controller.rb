# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_article, :only => [:edit, :update, :destroy, :reset_ratings, :properties_partial]
  before_filter :feature_enabled?, :only => [:index, :show, :new, :edit, :create, :update]
  

  def index
    redirect_to solution_category_folder_url(params[:category_id], params[:folder_id])
  end

  def show
    @enable_pattern = true
    @article = current_account.solution_articles.find_by_id!(params[:id], :include => [:folder, :draft])
    respond_to do |format|
      format.html {
        render (@feature ? "solution/articles/draft/show" : "show"), :formats => [:html]
      }
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
      format.html {
        render @feature ? "solution/articles/draft/new" : "new"
      }
      format.xml  { render :xml => @article }
    end
  end

  def edit
    respond_to do |format|
      format.html { # edit.html.erb 
        if @feature
          return unless load_draft
          render "solution/articles/draft/edit"
        end
      }
      format.xml  { render :xml => @article }
    end
  end

  def create
    current_folder = Solution::Folder.find(params[:solution_article][:folder_id]) 
    @article = current_folder.articles.new(params[nscname]) 
    set_item_user 

    redirect_to_url = @article
    redirect_to_url = new_solution_category_folder_article_path(params[:category_id], params[:folder_id]) unless params[:save_and_create].nil?
    build_attachments unless (@feature and save_as_draft?)
    set_solution_tags
    @article.set_default_status(!save_as_draft?)
    respond_to do |format|
      if @article.save
        (forge_draft if save_as_draft? and @feature )
        redirect_to_url = solution_category_folder_article_path(params[:category_id], params[:folder_id], @article) if @feature
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @article, :status => :created, :location => @article }
        format.json  { render :json => @article, :status => :created, :location => @article }
      else
        format.html { 
          render @feature ? "solution/articles/draft/new" : "new"
        }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def save_and_create    
    logger debug "Inside save and create"    
  end

  def update
    if @feature and (save_as_draft? || publish? || cancel_draft_changes?) 
      publish_article if publish?
      update_draft if (save_as_draft? or cancel_draft_changes?)
      return
    end
    update_article
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

  def properties_partial
    render "solution/articles/draft/article_properties_partial_form", :formats => [:html], :layout => false
  end

  protected

    def load_article
      p "#"*50, params
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

    def set_solution_tags
      return unless params[:tags] && (params[:tags].is_a?(Hash) && params[:tags][:name].present?)      
      @article.tags.clear    
      tags = params[:tags][:name]
      ar_tags = tags.split(',').map(&:strip).uniq    
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

    [:save_as_draft, :publish, :cancel_draft_changes, :update_properties].each do |meth|
      define_method "#{meth}?" do
        params[meth].present?
      end
    end

    def forge_draft
      @draft = @article.build_draft_from_article
      attachment_builder(@draft, params[:solution_article][:attachments], params[:cloud_file_attachments])
      @draft.save
    end

    def load_draft
      @draft = current_account.solution_drafts.find_by_article_id(params[:id])
      if @draft.present? and @draft.locked?
        flash[:error] = t('solution.articles.restrict_edit' , :name => @draft.current_author.name)
        redirect_to :action => "show" and return false
      end
      true
    end

    def publish_article
      @draft = current_account.solution_drafts.find_by_article_id(params[:id])
      if @draft.present? 
        update_draft_attributes
        @draft.publish!
        flash[:success] = "This article was published succesfully."
        redirect_to :action => "show" and return
      end
      @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
      flash[:success] = "This article was published succesfully."
      update_article
    end

    def update_draft
      @draft = current_account.solution_drafts.find_by_article_id(params[:id])
      # (redirect_to :action => "show" and return) if (!@draft.present? and cancel_draft_changes?)
      (flash[:not_empty], action = " ", "show") if (!@draft.present? and cancel_draft_changes?)
      if (@draft.present? && (@draft.current_author == current_user) && update_draft_attributes)
        flash[:success], action = "This article draft was saved succesfully.", "show"
      end
      unless @draft.present?
        @draft = @article.build_draft_from_article
        update_draft_attributes
        flash[:success], action = "This article draft was saved succesfully.", "show"
      end
      flash ||= {:error => "This article could not be saved."}
      redirect_to :action => (action || "edit") and return
    end

    def update_draft_attributes
      attachment_builder(@draft, params[:solution_article][:attachments], params[:cloud_file_attachments])
      @draft.unlock
      @draft.update_attributes(params[:solution_article].slice(:title, :description))
    end

    def update_article
      build_attachments unless update_properties?
      set_solution_tags
      update_params = update_properties? ? params[nscname].except(:title, :description) : params[nscname]
      respond_to do |format|    
        if @article.update_attributes(update_params)
          format.html { redirect_to :action => "show" }
          format.xml  { render :xml => @article, :status => :created, :location => @article }     
          format.json  { render :json => @article, :status => :ok, :location => @article }
          format.js {
            flash[:notice] = t('solution.articles.prop_updated_msg')
          }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
        end
      end
    end

end

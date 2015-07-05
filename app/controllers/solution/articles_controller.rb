# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  helper SolutionHelper
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_article, :only => [:edit, :update, :destroy, :reset_ratings, :properties]
  before_filter :old_folder, :cleanup, :only => [:move_to]
  before_filter :bulk_update_folder, :only => [:move_to, :move_back]
  before_filter :set_current_folder, :only => [:create]
  

  def index
    redirect_to solution_category_folder_url(params[:category_id], params[:folder_id])
  end

  def show
    @enable_pattern = true
    @article = current_account.solution_articles.find_by_id!(params[:id], :include => [:folder, :draft, :tickets])
    @page_title = (@article.draft || @article).title
    respond_to do |format|
      format.html {
        @current_item = @article.draft || @article
        render "show"
      }
      format.xml  { render :xml => @article }
      format.json { render :json => @article }
    end    
  end

  def new
    @page_title = t("header.tabs.new_solution")
    current_folder = Solution::Folder.first
    current_folder = Solution::Folder.find(params[:folder_id]) unless params[:folder_id].nil?
    @article = current_folder.articles.new    
    @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    respond_to do |format|
      format.html {
        render "new"
      }
      format.xml  { render :xml => @article }
    end
  end

  def edit
    @page_title = @article.title
    respond_to do |format|
      format.html {
        render_edit
      }
      format.xml  { render :xml => @article }
    end
  end

  def create
    @article = @current_folder.articles.new(params[nscname]) 
    set_item_user 

    build_attachments
    @article.set_status(!save_as_draft?)
    @article.tags_changed = set_solution_tags
    respond_to do |format|
      if @article.save
        format.html { 
          flash[:notice] = t('solution.articles.published_success',
                            :url => support_solutions_article_path(@article)).html_safe if publish?
          redirect_to creation_redirect_url 
        }
        format.xml  { render :xml => @article, :status => :created, :location => @article }
        format.json  { render :json => @article, :status => :created, :location => @article }
      else
        format.html { 
          render "new"
        }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def save_and_create    
    logger debug "Inside save and create"    
  end

  def update
    if save_as_draft? || publish? || cancel_draft_changes?
      publish? ? publish_article : (cancel_draft_changes? ? revert_draft_changes : update_draft)
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

  def properties
    render :layout => false
  end

  def voted_users
    @article = current_account.solution_articles.find(params[:id], :include =>[:votes => :user])
    render :layout => false
  end

  def move_to
    flash[:notice] = moved_flash_msg if @updated_items

    respond_to do |format|
      format.js { render 'solution/articles/move_to.rjs' }
    end
  end

  def move_back
    @folder = current_account.folders.find(params[:parent_id])
    respond_to do |format|
      format.js { render 'solution/articles/move_back.rjs' }
    end
  end

  def change_author
    @updated_items = []
    params[:items].each do |a|
      item = current_account.solution_articles.find(a)
      item.user_id = params[:parent_id]
      item.save
      @updated_items << item.id
    end
    @articles = current_account.solution_articles.find_all_by_id(params[:items])
    flash[:notice] = t("solution.flash.articles_changed_author") if @updated_items
    respond_to do |format|
      format.js { render 'solution/articles/change_author.rjs' }
    end
  end

  protected

    def cleanup
      params[:items] = params[:items].map(&:to_i)
      params[:parent_id] = params[:parent_id].to_i
    end

    def load_article
      @article = current_account.solution_articles.find(params[:id], :include =>[:draft])
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
      tags_changed = false
      return tags_changed unless params[:tags] && (params[:tags].is_a?(Hash) && !params[:tags][:name].nil?)  
         
      tags = params[:tags][:name]
      ar_tags = tags.split(',').map(&:strip).uniq    
      existing_tags = @article.tags.map(&:name)
      
      return tags_changed if ar_tags.sort == existing_tags.sort

      new_tag = nil

      @article.tags.clear    

      ar_tags.each do |tag|      
        new_tag = Helpdesk::Tag.find_by_name_and_account_id(tag, current_account) ||
           Helpdesk::Tag.new(:name => tag ,:account_id => current_account.id)
        begin
          @article.tags << new_tag
        rescue ActiveRecord::RecordInvalid => e
        end
      end

      @article.updated_at = Time.now
      tags_changed = true
    end
    
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to support_solutions_article_path(params[:id])
      elsif !privilege?(:view_solutions)
        access_denied
      end
    end

    [:save_as_draft, :publish, :cancel_draft_changes, :update_properties].each do |meth|
      define_method "#{meth}?" do
        params[meth].present?
      end
    end

    def load_draft
      @draft = @article.draft
      if @draft.present? and @draft.locked?
        redirect_to :action => "show" and return false
      end
      true
    end

    def publish_article
      @draft = @article.draft
      if @draft.present? 
        if update_draft_attributes and @draft.publish!
          flash[:notice] = t('solution.articles.published_success',
                               :url => support_solutions_article_path(@article)).html_safe
        else
          flash[:error] = t('solution.articles.published_failure')
        end
        redirect_to :action => "show" and return
      end
      @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
      update_article
    end

    def revert_draft_changes
      #TODO : Catch Errors and handle in cancelling draft
      if (@article.draft.present? && latest_content?)
        @draft = @article.draft
        if params[:previous_author].present?
          @draft.user = (User.find(params[:previous_author].to_i) || current_user)
          @draft.modified_at = Time.parse(params[:original_updated_at])
          update_draft_attributes
        else
          @draft.destroy
        end
      end
      respond_to do |format|
        format.html { redirect_to :action => "show" }
        format.js   { 
          flash[:notice] = t('solution.articles.draft.revert_msg');
          render 'draft_reset'
        }
      end
    end

    def update_draft
      @draft = @article.draft
      if (@draft.blank? || (@draft.user == current_user))
        @draft = @article.build_draft_from_article if @draft.blank?
        unless update_draft_attributes
          flash[:error], action = t('solution.articles.draft.save_error'), "edit"
        end    
      end
      redirect_to :action => (action || "show") and return
    end

    def latest_content?
      params[:last_updated_at].to_i == @article.draft.updation_timestamp || params[:previous_author].blank?
    end

    def update_draft_attributes
      attachment_builder(@draft, params[:solution_article][:attachments], params[:cloud_file_attachments])
      @draft.unlock
      @draft.update_attributes(params[:solution_article].slice(:title, :description))
    end

    def update_article
      build_attachments unless update_properties?
      @article.tags_changed = set_solution_tags
      update_params = update_properties? ? params[nscname].except(:title, :description) : params[nscname]
      respond_to do |format|    
        if @article.update_attributes(update_params)
          format.html { 
            flash[:notice] = t('solution.articles.published_success', 
              :url => support_solutions_article_path(@article)).html_safe if publish?
            redirect_to :action => "show" 
          }
          format.xml  { render :xml => @article, :status => :created, :location => @article }     
          format.json  { render :json => @article, :status => :ok, :location => @article }
          format.js {
            flash[:notice] = t('solution.articles.prop_updated_msg')
          }
        else
          format.html { render_edit }
          format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
        end
      end
    end

    def creation_redirect_url    
      return @article if params[:save_and_create].nil?
      new_solution_category_folder_article_path(params[:category_id], params[:folder_id])
    end

    def render_edit
      return if !load_draft
      redirect_to "#{solution_article_path(@article)}#edit"
    end

    def bulk_update_folder
      @updated_items = []
      params[:items].each do |a|
        item = current_account.solution_articles.find(a)
        if item
          item.folder_id = params[:parent_id]
          item.save
          @updated_items << item.id
        end
      end
    end

    def old_folder
      @folder_id = current_account.solution_articles.find(params[:items].first).folder_id
      @number_of_articles = current_account.folders.find(@folder_id).articles.size
    end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.articles_move_to",
                      :folder_name => current_account.folders.find(params[:parent_id]).name,
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'articles_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @folder_id
                                    })
                  )).html_safe
    end

    def set_current_folder
      begin
        folder_id = params[:solution_article][:folder_id] || current_account.solution_folders.find_by_is_default(true).id
        @current_folder = Solution::Folder.find(folder_id)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        @current_folder = current_account.solution_folders.first
      end
    end

end

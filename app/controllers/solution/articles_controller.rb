# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  include Solution::LanguageControllerMethods
  helper SolutionHelper
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_meta_objects, :only => [:show, :new, :edit, :update, :properties, :destroy]
  before_filter :load_article, :only => [:show, :edit, :update, :destroy, :reset_ratings, :properties]
  before_filter :old_folder, :only => [:move_to]
  before_filter :check_new_folder, :bulk_update_folder, :only => [:move_to, :move_back]
  before_filter :set_current_folder, :only => [:create]
  before_filter :check_new_author, :only => [:change_author]
  before_filter :validate_author, :only => [:update]
  
  UPDATE_FLAGS = [:save_as_draft, :publish, :cancel_draft_changes]

  def index
    redirect_to solution_category_folder_url(params[:category_id], params[:folder_id])
  end

  def show
    @article = current_account.solution_articles.new unless @article
    respond_to do |format|
      format.html {
        if @article 
          @current_item = @article.draft || @article
          @page_title = @current_item.title
        end
      }
      format.xml  { render :xml => @article }
      format.json { render :json => @article }
    end    
  end

  def new
    @page_title = t("header.tabs.new_solution")
    @article = current_account.solution_articles.new
    set_article_folder
    @article.set_status(false)
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
    builder_params
    @article_meta = Solution::Builder.article(params)
    load_article_version
    @article.tags_changed = set_solution_tags
    @article.create_draft_from_article if save_as_draft?
    respond_to do |format|
      if @article
        format.html { 
          flash[:notice] = t('solution.articles.published_success',
                            :url => support_solutions_article_path(@article)).html_safe if publish?
          redirect_to solution_article_version_path(
                          @article_meta,
                          @article.language.code)
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
    load_article_version  
    unless (UPDATE_FLAGS & params.keys.map(&:to_sym)).any?
      update_article
      return 
    end
    send("article_#{(UPDATE_FLAGS & params.keys.map(& :to_sym)).first}")
  end

  def destroy
    redirect_path = solution_folder_path(@article_meta.solution_folder_meta_id)
    @article_meta.destroy
    
    respond_to do |format|
      format.html { redirect_to redirect_path }
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
    @article.reset_ratings
    @article.reload
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
    @article_meta = current_account.solution_article_meta.find_by_id!(params[:id])
    @article = @article_meta.solution_articles.find_by_language_id(params[:language_id], :include =>[:votes => :user])
    render :layout => false
  end

  def move_to
    flash[:notice] = moved_flash_msg if @updated_items.present?
    flash[:error] = error_flash_msg if @other_items.present?
  end

  def move_back
  end

  def change_author
    @articles = current_account.solution_articles.where(:id => params[:items])
    @articles.update_all(:user_id => params[:parent_id])
    @updated_items = @articles.map(&:id)

    flash[:notice] = t("solution.flash.articles_changed_author") if @updated_items
  end

  protected

    def load_article
      @article = @article_meta.send(language_scoper)
    end

    def scoper #possible dead code
      eval "Solution::#{cname.classify}"
    end

    def build_attachments
      attachment_builder(@article, params[nscname][:attachments], params[:cloud_file_attachments] )
    end
    
    def reorder_scoper
      current_account.solution_folder_meta.find(params[:folder_id]).solution_article_meta
    end
    
    def reorder_redirect_url
      solution_category_folder_url(params[:category_id], params[:folder_id])
    end

    def meta_scoper
      current_account.solution_article_meta
    end

    def cname #possible dead code
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end

    def load_meta_objects
      id = get_meta_id
      return if id.blank?
      @article_meta = current_account.solution_article_meta.find_by_id!(id)
      @folder_meta = @article_meta.solution_folder_meta
      @category_meta = @folder_meta.solution_category_meta
    end

    def get_meta_id
      id = params[:solution_article_meta][:id] if params[:solution_article_meta].present?
      id ||= params[:id] || params[:article_id]
    end
    
    def set_item_user
      @article.user ||= current_user if (@article.respond_to?('user=') && !@article.user_id)
      @article.account ||= current_account
    end

    def set_user
      params[:solution_article_meta][language_scoper.to_sym][:user_id] ||= current_user.id
    end

    def set_selected_tab
      @selected_tab = :solutions
    end     
    
    def page_title
      @page_title = t("header.tabs.solutions")    
    end

    def builder_params
      params[:solution_article_meta][language_scoper.to_sym] = {}
      params[:solution_article_meta][language_scoper.to_sym].merge!(params[nscname])
      params[:solution_article_meta][language_scoper.to_sym][:cloud_file_attachments] = params[:cloud_file_attachments]
      set_user
      set_status
    end

    def set_solution_tags
      return false unless tags_present? 
      set_tags_input
      return false unless tags_changed?
      @article.tags.clear   
      @tags_input.each do |tag|      
        begin
          @article.tags << Helpdesk::Tag.where(:name => tag, :account_id => current_account.id).first_or_initialize
        rescue ActiveRecord::RecordInvalid => e
        end
      end
      @article.updated_at = Time.now
      return true
    end

    def tags_present?
      params[:tags] && (params[:tags].is_a?(Hash) && !params[:tags][:name].nil?)
    end

    def set_tags_input
      @tags_input = params[:tags][:name].split(',').map(&:strip).uniq   
    end

    def tags_changed?
      !(@tags_input.sort == @article.tags.map(&:name).sort)
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

    def article_publish
      @draft = @article.draft
      if @draft.present? 
        if update_draft_attributes and @draft.publish!
          flash[:notice] = t('solution.articles.published_success',
                               :url => support_solutions_article_path(@article)).html_safe
          redirect_to :action => "show"
        else
          flash[:error] = show_draft_errors || t('solution.articles.published_failure')
          redirect_to solution_article_path(@article.id, :anchor => "edit")
        end
        return
      end
      @article.set_status(true)
      update_article
    end

    def article_cancel_draft_changes
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

    def article_save_as_draft
      @draft = @article.draft
      if (@draft.blank? || (@draft.user == current_user))
        @draft = @article.build_draft_from_article if @draft.blank?
        unless update_draft_attributes
          show_draft_errors
          flash[:error] ||= t('solution.articles.draft.save_error')
          redirect_to solution_article_path(@article.id, :anchor => "edit")
          return
        end    
      end
      redirect_to :action => "show"
    end

    def latest_content?
      params[:last_updated_at].to_i == @article.draft.updation_timestamp || params[:previous_author].blank?
    end

    def update_draft_attributes
      attachment_builder(@draft, params[:solution_article][:attachments], params[:cloud_file_attachments])
      @draft.unlock
      @draft.article.update_attributes(params[:solution_article].slice(:folder_id)) if params[:solution_article][:folder_id].present?
      @draft.update_attributes(params[:solution_article].slice(:title, :description))
    end

    def update_article
      build_attachments unless update_properties?
      @article.tags_changed = set_solution_tags
      update_params = update_properties? ? params[nscname].except(:title, :description) : params[nscname]
      respond_to do |format|    
        if @article.update_attributes(update_params)
          @article.reload 
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
          format.js {
            flash[:notice] = t('solution.articles.prop_updated_error')
            render 'update_error'
          }
        end
      end
    end

    def validate_author
      return unless update_properties?
      new_author_id = params[:solution_article][:user_id]
      if new_author_id.present? && @article.user_id != new_author_id
        new_author = current_account.users.find_by_id(new_author_id)
        params[:solution_article] = params[:solution_article].except(:user_id) unless new_author && new_author.agent?
      end
    end

    def render_edit
      return if !load_draft
      redirect_to solution_article_path(@article, :anchor => "edit")
    end

    def bulk_update_folder
      @articles = meta_scoper.where(:id => params[:items])
      @articles.map { |a| a.update_attributes(:solution_folder_meta_id => params[:parent_id]) }
      @updated_items = params[:items].map(&:to_i) & @new_folder.solution_article_metum_ids
      @other_items = params[:items].map(&:to_i) - @updated_items
    end

    def old_folder
      @old_folder = meta_scoper.find(params[:items].first).solution_folder_meta
      @number_of_articles = @old_folder.solution_article_meta.size
    end

    def check_new_folder
      @new_folder = current_account.solution_folder_meta.find_by_id params[:parent_id]
      unless @new_folder
        flash[:notice] = t("solution.flash.articles_move_to_fail")
        respond_to do |format|
          format.js { render inline: "location.reload();" }
        end
      end
    end

    def check_new_author
      @new_author = current_account.technicians.find_by_id params[:parent_id]
      unless @new_author
        flash[:notice] = t("solution.flash.articles_change_author_fail")
        respond_to do |format|
          format.js { render inline: "location.reload();" }
        end
      end
    end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.articles_move_to_success",
                      :count => @updated_items.count - 1,
                      :folder_name => h(@new_folder.name.truncate(30)),
                      :article_name => h(meta_scoper.find(@updated_items.first).title.truncate(30)),
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'articles_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @folder_id,
                                      :action_on => 'articles'
                                    })
                  )).html_safe
    end

    def error_flash_msg
      t("solution.flash.articles_move_to_error",
                      :count => @other_items.count - 1,
                      :folder_name => h(@new_folder.name.truncate(30)),
                      :article_name => h(meta_scoper.find(@other_items.first).title.truncate(30))
        ).html_safe
    end

    def set_current_folder
      begin
        folder_id = params[:solution_article][:folder_id] || current_account.solution_folders.find_by_is_default(true).id
        @current_folder = current_account.solution_folders.find(folder_id)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        @current_folder = current_account.solution_folders.first
      end
    end

    def show_draft_errors
      draft = @article.draft || @draft
      if draft.present? && draft.errors.present?
        flash[:error] = draft.errors.full_messages.join("<br />\n").html_safe
      end
    end

    def set_status
      params[:solution_article_meta][language_scoper.to_sym][:status] ||= get_status
    end

    def get_status
      status = params[nscname][:status]
      return status.to_i == Solution::Article::STATUS_KEYS_BY_TOKEN[:published] if status.present?
      save_as_draft? ? false : publish?
    end

    def set_article_folder
      return if params[:folder_id].nil?
      @article.solution_folder_meta = current_account.solution_folder_meta.find_by_id(params[:folder_id])
    end

    def language_code
      lang = Language.find(params[:language_id])
      lang.code == current_account.language ? "primary" : lang.code
    end

    def load_article_version
      @article = @article_meta.send(language_code + "_article")
    end

end

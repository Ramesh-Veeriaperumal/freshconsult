# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  include Solution::LanguageControllerMethods
  helper SolutionHelper
  include Solution::FlashHelper
  include Solution::ControllerMethods
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_meta_objects, :only => [:show, :edit, :update, :properties, :destroy, :reset_ratings]
  before_filter :check_create_privilege, :only => [:show]
  before_filter :old_folder, :only => [:move_to]
  before_filter :check_new_folder, :bulk_update_folder, :only => [:move_to, :move_back]
  before_filter :set_current_folder, :only => [:create]
  # before_filter :check_new_author, :only => [:change_author]
  before_filter :validate_author, :language, :only => [:update]
  before_filter :cleanup_params_for_title, :only => [:show]
  before_filter :language_scoper, :only => [:new]
  before_filter :check_parent_params, :only => [:translate_parents]
  before_filter :set_parent_for_old_params, :only => [:create, :update]
  
  UPDATE_FLAGS = [:save_as_draft, :publish, :cancel_draft_changes]

  def index
    redirect_to solution_folder_path(params[:folder_id])
  end

  def show
    @article = @article_meta.send("build_#{language_scoper}") unless @article
    respond_to do |format|
      format.html {
        unless @article.new_record?
          @current_item = @article.draft || @article
          @page_title = @current_item.title
        else
          @page_title = t('solutions.new_translation', :language => language.name)
        end
      }
      format.xml  { render :xml => @article_meta, :include => [:folder] }
      format.json { render :json => @article_meta, :include => [:folder] }
    end    
  end

  def new
    @page_title = t("header.tabs.new_solution")
    @article_meta = current_account.solution_article_meta.new
    @article = @article_meta.solution_articles.new
    set_article_folder
    respond_to do |format|
      format.html {
        render "new"
      }
      format.xml  { render :xml => @article_meta }
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
    set_common_attributes
    @article_meta = Solution::Builder.article(params)
    @article = @article_meta.send(language_scoper)
    set_tags_changed
    @article.create_draft_from_article if save_as_draft?
    
    post_response(@article_meta, @article)
  end

  def update
    unless (UPDATE_FLAGS & params.keys.map(&:to_sym)).any?
      update_article
      return 
    end
    send("article_#{(UPDATE_FLAGS & params.keys.map(& :to_sym)).first}")
  end

  def destroy
    @article_meta.destroy
    
    destroy_response(solution_folder_path(@article_meta.solution_folder_meta_id))
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
    language_scoper
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

  # def change_author
  #   @articles = current_account.solution_articles.where(:id => params[:items])
  #   @articles.update_all(:user_id => params[:parent_id])
  #   @updated_items = @articles.map(&:id)

  #   flash[:notice] = t("solution.flash.articles_changed_author") if @updated_items
  # end

  def mark_as_uptodate
    meta_scoper.find(params[:item_id]).send("#{language.to_key}_article").update_attributes(:outdated => false)
    respond_to do |format|
      format.json { head :ok }
    end
  end

  def mark_as_outdated
    @article_meta = meta_scoper.find(params[:item_id])
    @article_meta.solution_articles.each do |a|
      next if a.is_primary?
      a.update_attributes(:outdated => true)
    end
    @article_meta.reload
    respond_to do |format|
      format.html { render :partial => "language_tabs" }
    end
  end

  def show_master
    @article_meta = current_account.solution_article_meta.find(params[:id])
    @item = params[:published].to_bool ? @article_meta.primary_article : @article_meta.draft
    respond_to do |format|
      format.html { render :partial => "popover_content" }
    end
  end

  def translate_parents
    @category_meta = Solution::Builder.category(params) if params[:solution_category_meta].present?
    @folder_meta = Solution::Builder.folder(params) if params[:solution_folder_meta].present?
  end

  protected

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
      @article = @article_meta.send(language_scoper)
      @folder_meta = @article_meta.solution_folder_meta
      @category_meta = @folder_meta.solution_category_meta
    end

    def get_meta_id
      params[:id] || params[:article_id] || (params[:solution_article_meta] || {})[:id]
    end
    
    # possible dead code
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
      tags = get_tags
      tags && (tags.is_a?(Hash) && !tags[:name].nil?)
    end

    def get_tags
      params[:tags] || (params[:solution_article_meta] && params[:solution_article_meta][language_scoper.to_sym][:tags])
    end

    def set_tags_input
      @tags_input = get_tags[:name].split(',').map(&:strip).uniq   
    end
    
    def set_tags_changed
      params_hash = (params.key?(:solution_article_meta) ? 
            params[:solution_article_meta][language_scoper.to_sym] : params[:solution_article])
      params_hash[:tags_changed] = set_solution_tags
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
          flash[:notice] = flash_message
          redirect_to multilingual_article_path(@article)
        else
          flash[:error] = show_draft_errors || t('solution.articles.published_failure')
          redirect_to multilingual_article_path(@article, :anchor => "edit")
        end
        return
      end
      set_status
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
        format.html { redirect_to multilingual_article_path(@article) }
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
          redirect_to multilingual_article_path(@article, :anchor => "edit")
          return
        end    
      end
      redirect_to multilingual_article_path(@article)
    end

    def latest_content?
      params[:last_updated_at].to_i == @article.draft.updation_timestamp || params[:previous_author].blank?
    end

    def update_draft_attributes
      attachment_builder(@draft, article_params[:attachments], params[:cloud_file_attachments])
      @draft.unlock
      @draft.article.solution_article_meta.update_attributes(params[:solution_article_meta].slice(:solution_folder_meta_id)) if params[:solution_article_meta][:solution_folder_meta_id].present?
      @draft.update_attributes(article_params.slice(:title, :description))
    end

    def article_params
      params[:solution_article_meta][language_scoper]
    end

    def update_article
      set_common_attributes
      set_tags_changed
      @article_meta = Solution::Builder.article(params)
      
      post_response(@article_meta, @article)
    end

    def validate_author
      return unless update_properties?
      new_params = params[:solution_article] || article_params
      new_author_id = new_params[:user_id]
      if new_author_id.present? && @article.user_id != new_author_id
        new_author = current_account.users.find_by_id(new_author_id)
        new_params.delete(:user_id) unless new_author && new_author.agent?
      end
    end

    def render_edit
      return if !load_draft
      redirect_to multilingual_article_path(@article, :anchor => "edit")
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

    # def check_new_author
    #   @new_author = current_account.technicians.find_by_id params[:parent_id]
    #   unless @new_author
    #     flash[:notice] = t("solution.flash.articles_change_author_fail")
    #     respond_to do |format|
    #       format.js { render inline: "location.reload();" }
    #     end
    #   end
    # end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.articles_move_to_success#{'_multilingual' if current_account.multilingual?}",
                      :count => @updated_items.count - 1,
                      :folder_name => h(@new_folder.name.truncate(30)),
                      :article_name => h(meta_scoper.find(@updated_items.first).title.truncate(30)),
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'articles_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @old_folder.id,
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

    def show_draft_errors
      draft = @article.draft || @draft
      if draft.present? && draft.errors.present?
        flash[:error] = draft.errors.full_messages.join("<br />\n").html_safe
      end
    end

    def cleanup_params_for_title
      params.slice!("id", "format", "controller", "action", "language")
    end

    def set_common_attributes  
      set_user_and_status
      if params[:solution_article_meta].present?
        merge_cloud_file_attachments
      end
    end

    def set_user_and_status
      if params[:solution_article].present?
        params[:solution_article][:status] ||= get_status
        params[:solution_article][:user_id] = current_user.id
      else
        params[:solution_article_meta][language_scoper.to_sym][:user_id] ||= current_user.id
        params[:solution_article_meta][language_scoper.to_sym][:status] ||= get_status
      end
    end

    def set_status
      params[:solution_article_meta][language_scoper.to_sym][:status] ||= get_status
    end

    def get_status
      status = (params[nscname] || {})[:status]
      status_keys = Solution::Article::STATUS_KEYS_BY_TOKEN
      return status_keys[:draft] if save_as_draft? || (status.present? && status_keys[:draft] == status.to_i)
      status_keys[:published]
    end

    def set_article_folder
      return if params[:folder_id].nil?
      @article_meta.solution_folder_meta_id = (current_account.solution_folder_meta.find_by_id(params[:folder_id]) || {})[:id]
    end

    def merge_cloud_file_attachments
      params[:solution_article_meta][language_scoper.to_sym].merge!({:cloud_file_attachments => params[:cloud_file_attachments]})
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
    
  	def multilingual_article_path(article, options={})
  		current_account.multilingual? ?
  			solution_article_version_path(article, options.slice(:anchor).merge({:language => article.language.code})) :
  			solution_article_path(article, options.slice(:anchor))
  	end

    def check_parent_params
      @article_meta = meta_scoper.find(params[:id])
      render_404 if incorrect_folder_meta || incorrect_category_meta
    end

    def incorrect_folder_meta
      @article_meta.solution_folder_meta_id.to_s != params[:solution_folder_meta][:id] if params[:solution_folder_meta].present?
    end

    def incorrect_category_meta
      @article_meta.solution_folder_meta.solution_category_meta_id.to_s != params[:solution_category_meta][:id] if params[:solution_category_meta].present?
    end
    
    def set_parent_for_old_params
      return unless params[:solution_article].present?
      params[:solution_article][:folder_id] = params[:folder_id]
      params[:solution_article][:id] = params[:id] if params[:id].present?
    end

    def check_create_privilege
      # The user has 'Create Folder/Category' privilege but not 'Publish Solution'. 
      # UI check : The link to add new version will not be available.
      # So when he hits the url directly to add new version, we render 404.
      return unless current_account.multilingual?
      render_404 unless privilege?(:publish_solution) || @article.present?
    end
end

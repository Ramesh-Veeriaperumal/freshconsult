class Solution::DraftsController < ApplicationController

  include Solution::DraftContext
  helper SolutionHelper
  helper Solution::ArticlesHelper

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :set_selected_tab, :only => [:index]
  before_filter :page_title, :only => [:index]
  before_filter :load_article_with_meta, :only => [:autosave, :publish, :destroy, :attachments_delete]
  before_filter :load_attachment, :only => [:attachments_delete]

  def index
    @drafts = drafts_scoper.as_list_view.paginate(:page => params[:page], :per_page => 10)
  end

  def destroy
    draft = @article.draft
    if draft.present? && !draft.locked?
      flash[:notice] = t('solution.articles.draft.discard_msg')
      draft.discarding = true
      draft.destroy
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { render :json => { :success => true} , :status => 200 }
      format.js   {
        flash[:notice] = t('solution.articles.draft.revert_msg');
        render 'solution/articles/draft_reset'
      }
    end
  end

  def publish
    redirect_to :back and return if @article.draft.present? && @article.draft.locked?
    if @article.solution_folder_meta.is_default?
      flash[:notice] = t('solution.articles.published_failure')
    else
      @article.draft.present? ? @article.draft.publish! : @article.publish!
      flash[:notice] = t('solution.articles.published_success',
                         :url => support_solutions_article_path(@article)).html_safe
    end
    redirect_to :back
  end

  def autosave
    @draft = current_account.solution_drafts.where(:article_id => @article.id).first_or_initialize
    @draft.category_meta_id ||= @draft.article.solution_folder_meta.solution_category_meta_id
    render :json => autosave_validate.to_json, :formats => [:js], :status => 200
  end

  def attachments_delete
    initialize_draft
    pseudo_delete_article_attachment
    @article.reload
    respond_to do |format|
      format.js { flash[:notice] = t('solution.articles.att_deleted') }
    end
  end

  private

    def scope
      params[:type] == 'all' ? [:in_portal, current_account.portals.find(get_portal_id)] : [:by_user, current_user]
    end

    def get_portal_id
      save_context
      @drafts_context
    end

    def set_selected_tab
      @selected_tab = :solutions
    end     

    def page_title
      @page_title = t("header.tabs.solutions")
    end

    def load_article_with_meta
      @article_meta = current_account.solution_article_meta.find_by_id!(params[:article_id])
      @article = @article_meta.solution_articles.find_by_language_id(params[:language_id], :include => :draft, :readonly => false)
    end

    def load_attachment
      @assoc = params[:attachment_type].pluralize.to_sym
      @attachment = @article.send(@assoc).find(params[:attachment_id])
    end

    def autosave_validate
      return autosave_content_validate if editable?
      autosave_response(:somebody_editing, {:name => @draft.user.name})
    end

    def editable?
      @draft.user_id == current_user.id || @draft.user_id == nil || !@draft.locked?
    end

    def initialize_draft
      @draft = @article.draft
      unless @article.draft.present? 
        @new_draft_record = true
        @draft = @article.create_draft_from_article
      end
    end

    def autosave_content_validate
      if content_changed?
        msg = (@draft.user_id == current_user.id) ? [:content_changed_you] : [:content_changed_other, {:name => @draft.user.name}]
        return autosave_response(*msg)
      end
      autosave_save_draft
    end

    def content_changed?
      !@draft.new_record? && (@draft.updation_timestamp != params[:timestamp].to_i)
    end

    def autosave_save_draft
      @draft.lock_for_editing! unless @draft.locked?
      if @draft.update_attributes(params.slice(*["description", "title"]))
        return autosave_response(:save_success, {}, true).merge({:timestamp => @draft.updation_timestamp})
      end
      autosave_response(:other_problem)
    end

    def autosave_response(key, lang_vars = {}, success = false)
      {
        :success => success,
        :msg => t("solution.draft.autosave.#{key}", lang_vars)
      }
    end

    def pseudo_delete_article_attachment
      deleted = { @assoc => [@attachment.id]}
      @draft.meta[:deleted_attachments] ||= {}
      @draft.meta[:deleted_attachments].merge!(deleted) { |key,oldval,newval| oldval | newval }

      @draft.save
    end

    def drafts_scoper
      if (params[:type] == 'all' and get_portal_id == 0)
        current_account.solution_drafts
      else
        current_account.solution_drafts.send(*scope)
      end
    end

    #META-READ-HACK!!
    def meta_folder_scope
      current_account.launched?(:meta_read) ?  :folder_through_meta : :folder
    end

    #META-READ-HACK!!
    def folder_scope_with_categories
      unless Account.current.present? && Account.current.launched?(:meta_read)
        return { :folder => {:category => :portals} }
      end
      { :folder_through_meta => {:category_through_meta => :portals_through_meta} }
    end
end
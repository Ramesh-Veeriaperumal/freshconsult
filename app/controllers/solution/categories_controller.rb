# encoding: utf-8
class Solution::CategoriesController < ApplicationController
  include Helpdesk::ReorderUtility
  helper SolutionHelper
  helper AutocompleteHelper
  helper Solution::NavmenuHelper
  helper Solution::ArticlesHelper
  include Solution::LanguageControllerMethods
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
  before_filter :portal_check, :only => [:index, :show]
  before_filter :set_selected_tab, :page_title
  before_filter :load_category, :only => [:destroy]
  before_filter :load_meta, :only => [:edit, :update]
  before_filter :load_category_with_folders, :only => [:show]
  before_filter :find_portal, :only => [:all_categories, :new, :create, :edit, :update]
  before_filter :set_modal, :only => [:new, :edit]
  before_filter :set_default_order, :only => :reorder
  before_filter :load_portal_solution_category_ids, :only => [:all_categories, :create, :update]

  def index
    @categories = current_portal.solution_category_meta.includes(:solution_folder_meta)

    respond_to do |format|
      format.html { @page_canonical = solution_categories_url }# index.html.erb
      format.xml  { render :xml => @categories.as_json(:root => false).to_xml(:root => "solution_categories") }
      format.json  { render :json => @categories.as_json(:include => folder_scope) }
    end
  end

  def all_categories
    @categories = @portal.solution_category_meta.includes(:primary_category, :portals).reject(&:is_default)
  end
  
  def navmenu
    render :partial=> '/solution/shared/navmenu_content'
  end

  def show
    @page_title = @category.name
    respond_to do |format|
      format.html {
        redirect_to solution_my_drafts_path('all') if @category.is_default?
      }
      format.xml {  render :xml => @category.to_xml(:include => folder_scope) }
      format.json  { render :json => @category.to_json(:include => folder_scope) }
    end
  end
  
  def new
    @page_title = t("header.tabs.new_solution_category")
    @category_meta = current_account.solution_category_meta.new
    @category = @category_meta.solution_categories.new
    respond_to do |format|
      format.html { render :layout => false if @modal }
      format.xml  { render :xml => @category }
    end
  end

  def edit
    @category = @category_meta.send(language_scoper)
    @primary = @category_meta.primary_category
    @category = current_account.solution_categories.new unless @category
    respond_to do |format|
      if @category_meta.is_default?
        flash[:notice] = I18n.t('category_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
        format.html { render  :layout => false if @modal }
      end
      format.xml  { render :xml => @category }
    end
  end

  def create
    @category = Solution::Builder.category(params)

    respond_to do |format|
      if @category.errors.blank?
        format.html { redirect_to solution_category_path(@category) }
        format.js { render 'after_save', :formats => [:rjs] }
        format.xml  { render :xml => @category, :status => :created, :location => @category.primary_category }
        format.json { render :json => @category, :status => :created, :location => @category.primary_category }
      else
        format.html { render :action => "new" }
        format.js { render 'after_save', :formats => [:rjs] }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
        format.json  { render :json => @category.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    language_scoper
    params[:solution_category][:id] = params[:id] if params[:solution_category].present?
    @category = Solution::Builder.category(params)
    respond_to do |format| 
      if @category.errors.blank?
        format.html { redirect_to solution_all_categories_path }
        format.js { render 'after_save', :formats => [:rjs] }
        format.xml  { render :xml => @category, :status => :created, :location => @category.primary_category }     
        format.json { render :json => @category, :status => :ok, :location => @category.primary_category }     
      else
        format.html { render :action => "edit" }
        format.js { render 'after_save', :formats => [:rjs] }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
        format.json  { render :json => @category.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @category.destroy unless @category.is_default?

    respond_to do |format|
      format.html {  redirect_to :action =>"index" }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  def sidebar
    @drafts = current_account.solution_drafts.preload({:article => :solution_article_meta})
    @my_drafts = current_account.solution_drafts.by_user(current_user).preload({:article => :solution_article_meta})
    @feedbacks = nil #current_account.tickets.all_article_tickets.unresolved
    @orphan_categories = orphan_categories
    render :partial => "/solution/categories/sidebar", :formats => [:html]
  end

  protected

    def scoper #possible dead code
      eval "Solution::#{cname.classify}"
    end                                     
    
    def page_title
      @page_title = t("header.tabs.solutions") 
    end
    
    def reorder_scoper
      (current_account.portals.find_by_id(params[:portal_id]) || current_portal).portal_solution_categories
    end
    
    def reorder_redirect_url
      solution_categories_path
    end

  private
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to (params[:id].present? && support_solution_path(params[:id])) || support_solutions_path
      elsif !privilege?(:view_solutions)
        access_denied
      end
    end
    
    def cname #possible dead code
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end
    
    def set_selected_tab
      @selected_tab = :solutions
    end
    
    def folder_scope
      { :folders => { :except => [:account_id,:import_id] }}
    end

    def account_scoper
      current_account.solution_categories
    end

    def meta_scoper
      current_account.solution_category_meta
    end

    def load_category
      @category = meta_scoper.find_by_id!(params[:id])
    end

    def load_meta
      @category_meta = meta_scoper.find_by_id(params[:id])
    end

    def find_portal
      @portal = current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end

    def load_category_with_folders
      #META-READ-HACK!!
      @category = meta_scoper.includes(:solution_folder_meta).find_by_id!(params[:id])
    end

    def set_modal
      @modal = true if request.xhr?
    end

    def orphan_categories
      current_account.solution_categories_from_cache.select { |cat| cat['portal_solution_categories'].empty?}
    end

    def set_default_order
      reorder_params_in_json = ActiveSupport::JSON.decode(params[:reorderlist])
      reorder_params_in_json[default_category.id.to_s] = reorder_params_in_json.length + 1
      params[:reorderlist] = reorder_params_in_json.to_json
    end

    def default_category
      current_account.solution_category_meta.where(:is_default => true).first
    end

    def all_drafts
      current_account.solution_articles.all_drafts.includes(
        {:folder => {:category => :portals}})
    end

    def load_portal_solution_category_ids
      @portal_solution_category_ids = Hash[@portal.portal_solution_categories.map{|psc| [psc.solution_category_meta_id , psc.id] }]
    end
end

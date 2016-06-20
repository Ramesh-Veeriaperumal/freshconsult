# encoding: utf-8
class Solution::CategoriesController < ApplicationController
  include Helpdesk::ReorderUtility
  helper SolutionHelper
  helper AutocompleteHelper
  helper Solution::NavmenuHelper
  helper Solution::ArticlesHelper
  include Solution::LanguageControllerMethods
  include Solution::ControllerMethods
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
  before_filter :portal_check, :only => [:index, :show]
  before_filter :set_selected_tab, :page_title
  before_filter :load_meta, :only => [:edit, :update, :destroy]
  before_filter :load_category_with_folders, :only => [:show]
  before_filter :find_portal, :only => [:all_categories, :new, :create, :edit, :update]
  before_filter :set_default_order, :only => :reorder
  before_filter :load_portal_solution_category_ids, :only => [:all_categories, :create, :update]
  
  around_filter :run_on_slave, :only => :sidebar

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
    @page_title = @category_meta.name
    
    show_response(@category_meta, folder_scope)
  end
  
  def new
    @page_title = t("header.tabs.new_solution_category")
    @category_meta = current_account.solution_category_meta.new
    @category = @category_meta.solution_categories.new
    
    new_response(@category)
  end

  def edit
    @category = @category_meta.send(language_scoper)
    @primary = @category_meta.primary_category
    @category = current_account.solution_categories.new unless @category
    
    edit_response(@category_meta, @category)
  end

  def create
    @category_meta = Solution::Builder.category(params)
    @category = @category_meta.send(language_scoper)

    post_response(@category_meta, @category)
  end

  def update
    @category_meta = Solution::Builder.category(params)
    @category = @category_meta.send(language_scoper)

    post_response(@category_meta, @category)
  end

  def destroy
    @category_meta.destroy unless @category_meta.is_default?

    destroy_response(:action => "index")
  end

  def sidebar
    @drafts = current_account.solution_drafts.in_applicable_languages.preload({:article => :solution_article_meta})
    @my_drafts = current_account.solution_drafts.by_user(current_user).in_applicable_languages.preload({:article => :solution_article_meta})
    @feedbacks = current_account.
                    tickets.all_article_tickets.unresolved.
                    preload(:requester, :ticket_status, :article) if current_user.agent.all_ticket_permission
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

    def load_meta
      @category_meta = meta_scoper.find_by_id!(params[:id])
    end

    def find_portal
      @portal = (params[:portal_id] && current_account.portals.find_by_id(params[:portal_id])) || current_portal
    end

    def load_category_with_folders
      @category_meta = meta_scoper.includes(:solution_folder_meta).find_by_id!(params[:id])
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

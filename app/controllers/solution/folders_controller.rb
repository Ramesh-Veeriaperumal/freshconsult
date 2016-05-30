# encoding: utf-8
class Solution::FoldersController < ApplicationController
  include Helpdesk::ReorderUtility
  helper AutocompleteHelper
  helper SolutionHelper
  helper Solution::ArticlesHelper
  include Solution::LanguageControllerMethods
  include Solution::ControllerMethods

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  before_filter :set_selected_tab
  before_filter :load_meta, :only => [:edit, :update, :show]
  # to be done!
  before_filter :validate_and_set_customers, :only => [:create, :update]
  before_filter :set_parent_for_old_params, :only => [:create, :update]
  before_filter :old_category, :only => [:move_to]
  before_filter :check_new_category, :bulk_update_category, :only => [:move_to, :move_back]
  after_filter  :clear_cache, :only => [:move_to, :move_back]
  
  def index
    redirect_to solution_category_path(params[:category_id])
  end

  def show
    @page_title = @folder_meta.name
    
    show_response(@folder_meta, [:articles])
  end
  
  def new
    @page_title = t("header.tabs.new_folder")
    @folder_meta = current_account.solution_folder_meta.new
    @folder = @folder_meta.solution_folders.new
    if params[:category_id].present?
      @category_meta = current_account.solution_category_meta.find_by_id(params[:category_id]) 
      @folder_meta.solution_category_meta_id = (@category_meta || {})[:id]
    end
    
    new_response(@folder)
  end

  def edit
    @folder = @folder_meta.send(language_scoper)
    @primary = @folder_meta.primary_folder
    @folder = current_account.solution_folders.new unless @folder
    @customer_id = @folder_meta.customer_folders.collect { |cf| cf.customer_id.to_s }
    
    edit_response(@folder_meta, @folder)
  end

  def create
    @folder_meta = Solution::Builder.folder(params)
    @folder = @folder_meta.send(language_scoper)
    @category_meta = @folder_meta.solution_category_meta
   
    post_response(@folder_meta, @folder)
  end

  def update
    @folder_meta = Solution::Builder.folder(params)
    @folder = @folder_meta.send(language_scoper)
    
    post_response(@folder_meta, @folder)
  end

  def destroy
    @folder = meta_scoper.find_by_id!(params[:id])
    @folder.destroy unless @folder.is_default?
    
    destroy_response(solution_category_path(@folder.solution_category_meta_id))
  end

  def visible_to
    change_visibility if visibility_validate?
  end

  def move_to
    flash[:notice] = moved_flash_msg if @updated_items.present?
    flash[:error] = error_flash_msg if @other_items.present?
  end

  def move_back
  end

 protected

  def scoper #possible dead code
    eval "Solution::#{cname.classify}"
  end

  def reorder_scoper
    current_account.solution_category_meta.find(params[:category_id]).solution_folder_meta
  end
  
  def reorder_redirect_url
    solution_category_url(params[:category_id])
  end

  def meta_scoper
    current_account.solution_folder_meta
  end

  def load_meta
    @folder_meta = meta_scoper.find_by_id!(params[:id])
    @category_meta = @folder_meta.solution_category_meta
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
  
  def articles_scope #possible dead code
    {:articles => Solution::Constants::API_OPTIONS.merge(:include => {})}   
  end

  private
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to support_solutions_folder_path
      elsif !privilege?(:view_solutions)
        access_denied
      end
    end

    def portal_scoper
      current_portal.solution_categories
    end

    def validate_and_set_customers
      customer_ids = params[:customers] || ((params[nscname] || {})[:customer_folders_attributes] || {})[:customer_id]
      return if customer_ids.nil?
      customer_ids = customer_ids.join(',') if customer_ids.kind_of?(Array)
      valid_customer_ids = valid_customers(customer_ids) || []
      if params[nscname].present?
        params[nscname][:customer_folders_attributes] = valid_customer_ids
        return
      end
      params[:solution_folder_meta][:customer_folders_attributes] = {}
      params[:solution_folder_meta][:customer_folders_attributes] = valid_customer_ids
    end

    def visibility_validate?
      @visibility = params[:visibility].to_i if params[:visibility]
      Solution::FolderMeta::VISIBILITY.map { |v| v[2]}.include?(@visibility)
    end

    def valid_customers(customer_ids)
      current_account.companies.where({ :id => customer_ids.to_s.split(',') }).pluck(:id) if customer_ids.present?
    end

    def change_visibility
      @folders = meta_scoper.where(:id => params[:folderIds]).readonly(false)
      if @visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
        if valid_customers(params[:companies]).blank?
          flash[:notice] = t('solution.folders.visibility.no_companies')
          return
        end
        customer_ids, add_to_existing = [valid_customers(params[:companies]), (params[:addToExisting].to_i == 1)]
        change_result = @folders.map {|f| f.add_visibility(@visibility, customer_ids, add_to_existing)}.reduce(:&)
      else
        change_result = !(@folders.map {|f| f.update_attributes(:visibility => @visibility)}.include?(false))
      end
      @updated_folders = @folders.select { |f| f.valid? }
      @other_folders = @folders - @updated_folders
      flash[:notice] = visibility_update_flash_msg("success", @updated_folders) if @updated_folders.present?
      flash[:error] = visibility_update_flash_msg("failure", @other_folders) if @other_folders.present?
    end

    def bulk_update_category
      @folders = meta_scoper.where(:id => params[:items])
      @folders.map { |f| f.update_attributes(:solution_category_meta_id => params[:parent_id]) }
      @new_category.reload
      @updated_items = params[:items].map(&:to_i) & @new_category.solution_folder_metum_ids
      @other_items = params[:items].map(&:to_i) - @updated_items
    end

    def old_category
      @old_category = meta_scoper.find(params[:items].first).solution_category_meta
      @number_of_folders = @old_category.solution_folder_meta.size
    end

    def check_new_category
      @new_category = current_account.solution_category_meta.find_by_id params[:parent_id]
      unless @new_category
        flash[:notice] = t("solution.flash.folders_move_to_fail")
        respond_to do |format|
          format.js { render inline: "location.reload();" }
        end
      end
    end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.folders_move_to_success#{'_multilingual' if current_account.multilingual?}",
                      :count => @updated_items.count - 1,
                      :category_name => view_context.pjax_link_to(h(@new_category.name.truncate(30)), solution_category_path(@new_category.id)),
                      :folder_name => h(meta_scoper.find(@updated_items.first).name.truncate(30)),
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'folders_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @old_category.id,
                                      :action_on => 'folders'
                                    })
                  )).html_safe
    end

    def error_flash_msg
      t("solution.flash.folders_move_to_error",
                      :count => @other_items.count - 1,
                      :category_name => h(@new_category.name.truncate(30)),
                      :folder_name => h(meta_scoper.find(@other_items.first).name.truncate(30))
        ).html_safe
    end

    def visibility_update_flash_msg(flag, items)
      t("solution.flash.folders_visibility_"+flag,
                      :count => items.count - 1,
                      :folder_name => h(items.first.name.truncate(30))
        ).html_safe
    end

    def clear_cache
      current_account.clear_solution_categories_from_cache
    end

    def set_customers_field
      @customer_id = params["customers"].present? ? params["customers"].split(',') : []
    end

    def set_parent_for_old_params
      return unless params[:solution_folder].present?
      params[:solution_folder][:category_id] ||= params[:category_id]
    end
end

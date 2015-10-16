# encoding: utf-8
class Solution::FoldersController < ApplicationController
  include Helpdesk::ReorderUtility
  helper AutocompleteHelper
  helper SolutionHelper
  helper Solution::ArticlesHelper

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  before_filter :set_selected_tab, :page_title
  before_filter :load_category, :only => [:new, :show, :edit, :update, :destroy, :create]
  before_filter :fetch_new_category, :only => [:update, :create]
  before_filter :set_customer_folder_params, :validate_customers, :only => [:create, :update]
  before_filter :set_modal, :only => [:new, :edit]
  before_filter :old_category, :only => [:move_to]
  before_filter :check_new_category, :bulk_update_category, :only => [:move_to, :move_back]
  after_filter  :clear_cache, :only => [:move_to, :move_back]
  
  def index
    redirect_to solution_category_path(params[:category_id])
  end

  def show
    #META-READ-HACK!!    
    @folder = current_account.folders.find(params[:id], :include => { meta_article_scope => [:draft, :user]})
    @page_title = @folder.name
    respond_to do |format|
      format.html {
        redirect_to solution_my_drafts_path('all') if @folder.is_default?
      }
      format.xml  { render :xml => @folder.to_xml(:include => articles_scope) }
      format.json { render :json => @folder.as_json(:include => articles_scope) }
    end
  end
  

  def new
    @page_title = t("header.tabs.new_folder")
    @folder = current_account.folders.new
    @folder.category = @category if params[:category_id]
    respond_to do |format|
      format.html { render :layout => false if @modal }
      format.xml  { render :xml => @folder }
    end
  end

  def edit
    @folder = current_account.folders.find(params[:id])
    @page_title = @folder.name      
    @customer_id = @folder.customer_folders.collect { |cf| cf.customer_id.to_s }
    respond_to do |format|
      if @folder.is_default?
        flash[:notice] = I18n.t('folder_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
         format.html { render :layout => false if @modal }
      end
      format.xml  { render :xml => @folder }
    end
  end

  def create
    current_category = current_account.solution_categories.find(params[:category_id] || params[:solution_folder][:category_id])
    @folder = current_category.folders.new(params[nscname]) 
    @folder.category_id = @new_category.id
   
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @folder.save
        format.html { redirect_to solution_folder_path(@folder) }
        format.xml  { render :xml => @folder, :status => :created }
        format.json  { render :json => @folder, :status => :created }     
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def update
    @folder = current_account.solution_folders.where(:id => params[:id]).readonly(false).first

    @folder.category_id = @new_category.id
    
    respond_to do |format|     
      if @folder.update_attributes(params[nscname])       
        format.html do 
          redirect_to solution_folder_path(@folder.id)
        end
        format.xml  { render :xml => @folder, :status => :ok } 
        format.json  { render :json => @folder, :status => :ok }     
      else
        format.html { 
          set_customers_field
          render :action => "edit" 
        }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @folder = current_account.solution_folders.where( :id => params[:id]).readonly(false).first
    redirect_to_url = solution_category_url(@folder.category_id)
    @folder.destroy unless @folder.is_default?
    respond_to do |format|
      format.html { redirect_to redirect_to_url }
      format.xml  { head :ok }
      format.json  { head :ok }
    end
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

  def page_title
    @page_title = t("header.tabs.solutions")
  end

  def reorder_scoper
    current_account.solution_categories.find(params[:category_id]).folders
  end
  
  def reorder_redirect_url
    solution_category_url(params[:category_id])
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

    def load_category
      @category = current_account.solution_categories.find_by_id!(params[:category_id]) if params[:category_id]
    end

    def fetch_new_category
      if params[:solution_folder][:category_id]
        @new_category = current_account.solution_categories.find_by_id(params[:solution_folder][:category_id])
      end
      @new_category ||= @category
    end

    def set_customer_folder_params
      return unless params[nscname][:customer_folders_attributes].blank?
      params[nscname][:customer_folders_attributes] = {}
      params[nscname][:customer_folders_attributes][:customer_id] = params[:customers]  
    end

    def validate_customers
      customer_ids = params[nscname][:customer_folders_attributes][:customer_id] || []
      customer_ids = valid_customers(customer_ids) unless customer_ids.blank?
      params[nscname][:customer_folders_attributes][:customer_id] = customer_ids.blank? ? [] : customer_ids
    end

    def set_modal
      @modal = true if request.xhr?
    end

    def visibility_validate?
      @visibility = params[:visibility].to_i if params[:visibility]
      Solution::Folder::VISIBILITY.map { |v| v[2]}.include?(@visibility)
    end

    def valid_customers(customer_ids)
      current_account.companies.find_all_by_id(customer_ids.split(','), :select => "id").map(&:id) if customer_ids.present?
    end

    def change_visibility
      @folders = current_account.folders.where(:id => params[:folderIds]).readonly(false)
      if @visibility == Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
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
      @folders = current_account.folders.where(:id => params[:items]).readonly(false)
      @folders.map { |f| f.update_attributes(:category_id => params[:parent_id]) }
      @new_category.reload
      @updated_items = params[:items].map(&:to_i) & @new_category.folder_ids
      @other_items = params[:items].map(&:to_i) - @updated_items
    end

    def old_category
      @category_id = current_account.folders.find(params[:items].first).category_id
      @number_of_folders = current_account.solution_categories.find(@category_id).folders.size
    end

    def check_new_category
      @new_category = current_account.solution_categories.find_by_id params[:parent_id]
      unless @new_category
        flash[:notice] = t("solution.flash.folders_move_to_fail")
        respond_to do |format|
          format.js { render inline: "location.reload();" }
        end
      end
    end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.folders_move_to_success",
                      :count => @updated_items.count - 1,
                      :category_name => h(@new_category.name.truncate(30)),
                      :folder_name => h(current_account.solution_folders.find(@updated_items.first).name.truncate(30)),
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'folders_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @category_id,
                                      :action_on => 'folders'
                                    })
                  )).html_safe
    end

    def error_flash_msg
      t("solution.flash.folders_move_to_error",
                      :count => @other_items.count - 1,
                      :category_name => h(@new_category.name.truncate(30)),
                      :folder_name => h(current_account.solution_folders.find(@other_items.first).name.truncate(30))
        ).html_safe
    end

    def visibility_update_flash_msg(flag, items)
      t("solution.flash.folders_visibility_"+flag,
                      :count => items.count - 1,
                      :folder_name => h(items.first.name.truncate(30))
        ).html_safe
    end

    #META-READ-HACK!!    
    def meta_article_scope
      current_account.launched?(:meta_read) ?  :articles_through_meta : :articles
    end

    def clear_cache
      current_account.clear_solution_categories_from_cache
    end

    def set_customers_field
      @customer_id = params["customers"].present? ? params["customers"].split(',') : []
    end
end

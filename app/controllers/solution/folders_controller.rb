# encoding: utf-8
class Solution::FoldersController < ApplicationController
  include Helpdesk::ReorderUtility
  helper AutocompleteHelper
  helper SolutionHelper
  helper Solution::ArticlesHelper

  include FeatureCheck
  feature_check :solution_drafts

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  before_filter :set_selected_tab, :page_title
  before_filter :load_category, :only => [:new, :show, :edit, :update, :destroy, :create]
  before_filter :fetch_new_category, :only => [:update, :create]
  before_filter :set_customer_folder_params, :validate_customers, :only => [:create, :update]
  before_filter :set_modal, :only => [:new, :edit]
  before_filter :old_category, :cleanup, :only => [:move_to]
  before_filter :bulk_update_category, :only => [:move_to, :move_back]
  
  def index
    redirect_to solution_category_path(params[:category_id])
  end

  def show    
    @folder = current_account.folders.find(params[:id], :include => {:articles => [:draft, :user]})
    
    respond_to do |format|
      format.html {
        redirect_to "/solution/drafts/all" if @folder.is_default?
      }
      format.xml  { render :xml => @folder.to_xml(:include => articles_scope) }
      format.json { render :json => @folder.as_json(:include => articles_scope) }
    end
  end
  

  def new
    @folder = current_account.folders.new
    @folder.category = @category if params[:category_id]
    respond_to do |format|
      format.html { render :layout => false if @modal }
      format.xml  { render :xml => @folder }
    end
  end

  def edit
    @folder = current_account.folders.find(params[:id])      
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

    redirect_to_url = solution_category_path(@new_category.id)
    redirect_to_url = new_solution_category_folder_path(@new_category.id) unless
      params[:save_and_create].nil?
   
    #@folder = current_account.solution_folders.new(params[nscname]) 
    respond_to do |format|
      if @folder.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @folder, :status => :created }
        format.json  { render :json => @folder, :status => :created }     
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def update
    @folder = @category.folders.find(params[:id])

    @folder.category_id = @new_category.id
    
    respond_to do |format|     
      if @folder.update_attributes(params[nscname])       
        format.html do 
          redirect_to solution_folder_path(@folder.id)
        end
        format.xml  { render :xml => @folder, :status => :ok } 
        format.json  { render :json => @folder, :status => :ok }     
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @folder.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @folder = @category.folders.find(params[:id])
    
    @folder.destroy unless @folder.is_default?
    
    redirect_to_url = solution_category_url(params[:category_id])
    
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
    flash[:notice] = moved_flash_msg if @updated_items

    respond_to do |format|
      format.js { render 'solution/folders/move_to.rjs' }
    end
  end

  def move_back
    @category = current_account.solution_categories.find(params[:parent_id])
    respond_to do |format|
      format.js { render 'solution/folders/move_back.rjs' }
    end
  end

 protected

  def cleanup
    params[:items] = params[:items].map(&:to_i)
    params[:parent_id] = params[:parent_id].to_i
  end

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
        @new_category = portal_scoper.find_by_id(params[:solution_folder][:category_id])
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
      Solution::Folder::VISIBILITY.map { |v| v[2]}.include?(params[:visibility].to_i)
    end

    def valid_customers(customer_ids)
      current_account.companies.find_all_by_id(customer_ids.split(','), :select => "id").map(&:id)
    end

    def change_visibility
      visibility = params[:visibility].to_i
      customer_ids, add_to_existing = [], false
      if visibility == Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
        customer_ids = valid_customers(params[:companies])
        if customer_ids.blank?
          flash[:notice] = t('solution.folders.visibility.no_companies')
          return
        end
        add_to_existing = (params[:addToExisting].to_i == 1)
      end
      
      @folders = current_account.folders.find_all_by_id(params[:folderIds])
      @folders.each do |folder|
        if folder.add_visibility(visibility, customer_ids, add_to_existing)
          flash[:notice] = t('solution.folders.visibility.success')
        end
      end
    end

    def bulk_update_category
      @updated_items = []
      params[:items].each do |f|
        item = current_account.folders.find(f)
        item.category_id = params[:parent_id]
        item.save
        @updated_items << item.id
      end
    end

    def old_category
      @category_id = current_account.folders.find(params[:items].first).category_id
    end

    def moved_flash_msg
      render_to_string(
      :inline => t("solution.flash.folders_move_to",
                      :category_name => current_account.solution_categories.find(params[:parent_id]).name,
                      :undo => view_context.link_to(t('undo'), '#', 
                                    :id => 'folders_undo_bulk',
                                    :data => { 
                                      :items => @updated_items, 
                                      :parent_id => @category_id
                                    })
                  )).html_safe
    end

end

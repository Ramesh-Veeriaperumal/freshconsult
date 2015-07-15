# encoding: utf-8
class Solution::FoldersController < ApplicationController
  include Helpdesk::ReorderUtility
  helper AutocompleteHelper

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  before_filter :set_selected_tab, :page_title
  before_filter :load_category, :only => [:show, :edit, :update, :destroy, :create]
  before_filter :fetch_new_category, :only => [:update, :create]
  before_filter :set_customer_folder_params, :validate_customers, :only => [:create, :update]
  
  def index
    redirect_to solution_category_path(params[:category_id])
  end

  def show    
    @item = @category.folders.find(params[:id])
    #META-READ-CHECK
    
    respond_to do |format|
      format.html { @page_canonical = solution_category_folder_url(@category, @item) }
      format.xml  { render :xml => @item.to_xml(:include => articles_scope) }
      format.json { render :json => @item.as_json(:include => articles_scope) }
    end
  end
  

  def new    
    current_category = current_account.solution_categories.find(params[:category_id])
    @folder = current_category.folders.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @folder }
    end
  end

  def edit
    @folder = @category.folders.find(params[:id])      
    @customer_id = @folder.customer_folders.collect { |cf| cf.customer_id.to_s }
    respond_to do |format|
      if @folder.is_default?
        flash[:notice] = I18n.t('folder_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
         format.html # edit.html.erb
      end
      format.xml  { render :xml => @folder }
    end
  end

  def create
    current_category = current_account.solution_categories.find(params[:category_id])    
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
          redirect_to solution_category_folder_path(@new_category.id, @folder.id)
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
      @category = portal_scoper.find_by_id!(params[:category_id])
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
      customer_ids = current_account.companies.find_all_by_id(customer_ids.split(','), :select => "id").map(&:id) unless customer_ids.blank?
      params[nscname][:customer_folders_attributes][:customer_id] = customer_ids.blank? ? [] : customer_ids
    end

end

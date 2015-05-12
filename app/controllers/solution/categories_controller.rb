# encoding: utf-8
class Solution::CategoriesController < ApplicationController
  include Helpdesk::ReorderUtility
  include Solution::MetaControllerMethods
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
  before_filter :portal_check, :only => [:index, :show]
  before_filter :set_selected_tab, :page_title
  before_filter :load_category, :only => [:edit, :update, :destroy]
  before_filter :load_category_with_folders, :only => [:show]

  def index
    @categories = current_portal.solution_categories

    respond_to do |format|
      format.html { @page_canonical = solution_categories_url }# index.html.erb
      format.xml  { render :xml => @categories }
      format.json  { render :json => @categories.to_json(:except => [:account_id,:import_id],
                                                         :include => folder_scope) }
    end
  end

  def show
    respond_to do |format|
      format.html { @page_canonical = solution_category_url(@item) }# index.html.erb
      format.xml {  render :xml => @item.to_xml(:include => folder_scope) }
      format.json  { render :json => @item.to_json(:except => [:account_id,:import_id],
                                                  :include => folder_scope) }
    end
  end
  
  def new
    @category = current_account.solution_categories.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @category }
    end
  end

  def edit
    respond_to do |format|
      if @category.is_default?
        flash[:notice] = I18n.t('category_edit_not_allowed')
        format.html {redirect_to :action => "show" }
      else
        format.html # edit.html.erb
      end
      format.xml  { render :xml => @category }
    end
  end

  def create
    @category = @meta_obj.solution_categories.build(params[nscname])
    redirect_to_url = solution_categories_url
    redirect_to_url = new_solution_category_path unless params[:save_and_create].nil?
    
    respond_to do |format|
      if @meta_obj.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @category, :status => :created, :location => @category }
        format.json { render :json => @category, :status => :created, :location => @category }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format| 
      if @category.update_attributes(params[nscname])       
        format.html { redirect_to :action =>"index" }
        format.xml  { render :xml => @category, :status => :created, :location => @category }     
        format.json { render :json => @category, :status => :ok, :location => @category }     
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @category.errors, :status => :unprocessable_entity }
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

  protected

    def scoper #possible dead code
      eval "Solution::#{cname.classify}"
    end                                     
    
    def page_title
      @page_title = t("header.tabs.solutions") 
    end
    
    def reorder_scoper
      current_portal.portal_solution_categories
    end
    
    def reorder_redirect_url
      solution_categories_path
    end

  private
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to support_solutions_path
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

    def meta_parent
      "solution_category_meta"
    end
    
    def folder_scope
      { :folders => { :except => [:account_id,:import_id] }}
    end

    def portal_scoper
      current_portal.solution_categories
    end

    def load_category
      @category = portal_scoper.find_by_id!(params[:id])
    end

    def load_category_with_folders
      @item = portal_scoper.find_by_id!(params[:id], :include => :folders)
    end
end

# encoding: utf-8
class Solution::CategoriesController < ApplicationController
  include Helpdesk::ReorderUtility
  rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler
  
  skip_before_filter :check_privilege, :only => [:index, :show]
  before_filter :portal_check, :only => [:index, :show]
  
  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :portal_category?, :except => :index
  before_filter :set_selected_tab     
  before_filter :page_title
  
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
    @item = current_account.solution_categories.find(params[:id], :include => :folders)
    
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
    @category = current_account.solution_categories.find(params[:id])      
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
    @category = current_account.solution_categories.new(params[nscname]) 
     
    redirect_to_url = solution_categories_url
    redirect_to_url = new_solution_category_path unless params[:save_and_create].nil?
    
    respond_to do |format|
      if @category.save
        format.html { redirect_to redirect_to_url }
        format.xml  { render :xml => @category, :status => :created, :location => @category }
        format.json { render :json => @category, :status => :created, :location => @category }
      else
        format.html { render :action => "new" }
        http_code = Error::HttpErrorCode::HTTP_CODE[:unprocessable_entity] 
        format.any(:xml, :json) { 
          api_responder({:message => "Solution category creation failed" ,:http_code => http_code, :error_code => "Unprocessable Entity", :errors => @category.errors})
        }
      end
    end
  end

  def update
    @category = current_account.solution_categories.find(params[:id]) 
    
    respond_to do |format| 
      if @category.update_attributes(params[nscname])       
        format.html { redirect_to :action =>"index" }
        format.xml  { render :xml => @category, :status => :created, :location => @category }     
        format.json { render :json => @category, :status => :ok, :location => @category }     
      else
        format.html { render :action => "edit" }
        http_code = Error::HttpErrorCode::HTTP_CODE[:unprocessable_entity] 
        format.any(:xml, :json) { 
          api_responder({:message => "Solution category update failed" ,:http_code => http_code, :error_code => "Unprocessable Entity", :errors => @category.errors})
        }
      end
    end
  end

  def destroy
    @category = current_account.solution_categories.find(params[:id])
    @category.destroy unless @category.is_default?

    respond_to do |format|
      format.html {  redirect_to :action =>"index" }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  protected

    def scoper
      eval "Solution::#{cname.classify}"
    end                                     
    
    def page_title
      @page_title = t("header.tabs.solutions") 
    end
    
    def reorder_scoper
      current_account.solution_categories
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
    
    def cname
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end
    
    def set_selected_tab
      @selected_tab = :solutions
    end
    
    def portal_category?
      wrong_portal unless(main_portal? || 
            (params[:id] && params[:id].to_i == current_portal.solution_category_id))
    end
    
    def folder_scope
      :folders
    end

    def RecordNotFoundHandler
      respond_to do |format|
        format.html {
          flash[:notice] = I18n.t(:'flash.category.page_not_found')
          redirect_to solution_categories_path
        }
        if params[:error] == "new"
          result = "Record Not Found"
          http_code = Error::HttpErrorCode::HTTP_CODE[:not_found]
          format.any(:xml, :json) {
            api_responder({:message => result ,:http_code => http_code, :error_code => "Not found"})
          }
        end
      end
    end
end

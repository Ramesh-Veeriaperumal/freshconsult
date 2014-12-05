# encoding: utf-8
class CompaniesController < ApplicationController
  
  include HelpdeskControllerMethods
  
  before_filter :set_selected_tab
  before_filter :load_item,  :only => [:show, :edit, :update, :update_company, :sla_policies]
  before_filter :build_item, :only => [:quick, :new, :create, :create_company]
  before_filter :set_required_fields, :only => [:create_company, :update_company]
  before_filter :set_validatable_custom_fields, :only => [:create, :update, :create_company, :update_company]

  def index
    per_page = (!params[:per_page].blank? && params[:per_page].to_i >= 500) ? 500 :  50
    respond_to do |format|
      format.html do
        @companies = current_account.companies.filter(params[:letter],params[:page], per_page)
      end
      format.xml  do
        render :xml => es_scoper(per_page)
      end
      format.json do
        render :json => es_scoper(per_page)
      end
    end
  end

  def show
    respond_to do |format|
      format.html { 
        @total_company_tickets = 
          current_account.tickets.permissible(current_user).all_company_tickets(@company.id).visible
        @company_tickets       = @total_company_tickets.newest(10).find(:all, 
                                  :include => [:ticket_states,:ticket_status,:responder,:requester])
        @company_users         = @company.users.contacts
        @company_users_size    = @company_users.size
        render :action => 'newshow'
      }
      format.xml  { render :xml => @company }
      format.json { render :json=> @company.to_json }
    end
  end
  
  def quick
    if @company.save  
      flash[:notice] = t(:'company.created')
    else
      flash[:notice] = activerecord_error_list(@company.errors)
    end
   redirect_to(companies_url)
  end

  def create
    respond_to do |format|
      if @company.save
        format.html { redirect_to(@company, :notice => t(:'company.created')) }
        format.xml  { render :xml => @company, :status => :created, :location => @company }
        format.json { render :json => @company, :status => :created }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        format.json { render :json => @company.errors, :status => :unprocessable_entity }
      end
    end
  end

  def create_company # new method to implement dynamic validations, as many forms post to create action 
    create
  end

  def update
    respond_to do |format|
      if @company.update_attributes(params[:company])
        format.html { redirect_to(@company, :notice => t(:'company.updated')) }
        format.xml  { head :ok }
        format.json { render :json => "", :status => :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        format.json { render :json => @company.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update_company # new method to implement dynamic validations, as many forms post to update action 
    update
  end

  def sla_policies
    render :layout => false
  end
  
  protected

    def scoper
      current_account.companies
    end

    def build_item
      @company = scoper.new
      @company.attributes = params[:company]
    end

    def es_scoper(per_page)
      order_by = (params[:order_by] == "updated_at") ? :updated_at : :name
      order_type = (params[:order_type] == "desc") ? 'desc' : 'asc'
      Company.es_filter(current_account.id,params[:letter],(params[:page] || 1),order_by, 
                                                                              order_type, per_page)
    end

    def set_selected_tab
      @selected_tab = :customers
    end

    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end

    def after_destroy_url
      return companies_url
    end

    def set_required_fields
      @company ||= scoper.new
      @company.required_fields = { :fields => current_account.company_form.agent_required_company_fields, 
                                :error_label => :label }
    end

    def set_validatable_custom_fields
      @company ||= scoper.new
      @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields, 
                                          :error_label => :label }
    end
end
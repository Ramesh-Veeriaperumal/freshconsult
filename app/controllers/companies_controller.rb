# encoding: utf-8
class CompaniesController < ApplicationController
  
  include HelpdeskControllerMethods
  include ExportCsvUtil
  include CompaniesHelperMethods
  
  before_filter :set_selected_tab
  before_filter :load_item,  :only => [:show, :edit, :update, :update_company, :update_notes, :sla_policies]
  before_filter :build_item, :only => [:quick, :new, :create, :create_company]
  before_filter :set_required_fields, :only => [:create_company, :update_company]
  before_filter :set_validatable_custom_fields, :only => [:create, :update, :create_company, :update_company]
  before_filter :set_native_mobile, :only => [:update]

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
        define_company_properties
        render :action => :newshow
      }
      format.xml  { render :xml => @company }
      format.json { render :json=> @company.to_json }
    end
  end
  
  def quick
    if @company.save  
      flash[:notice] = t(:'company.created')
    else
      check_domain_exists
      flash[:notice] = activerecord_error_list(@company.errors)
    end
   redirect_to(companies_url)
  end

  def create
    respond_to do |format|
      if @company.save
        flash[:notice] = t('company.created_view', :company_url => company_path(@company)).html_safe
        format.html { redirect_to companies_url }
        format.xml  { render :xml => @company, :status => :created, :location => @company }
        format.json { render :json => @company, :status => :created }
      else
        check_domain_exists
        format.html { render :action => "new" }
        format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        format.json { render :json => @company.errors.fd_json, :status => :unprocessable_entity }
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
        format.nmobile { render :json => { :success => true }}
      else
        check_domain_exists
        format.html { render :action => "edit" }
        format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        format.json { render :json => @company.errors.fd_json, :status => :unprocessable_entity }
        format.nmobile { render :json => { :success => false ,:err => @company.errors.full_messages ,:status => :unprocessable_entity } }
      end
    end
  end

  def update_company # new method to implement dynamic validations, as many forms post to update action 
    update
  end

  def update_notes
    respond_to do |format|
      if @company.update_attributes(params[:company])
        format.html { redirect_to(@company, :notice => t(:'company.updated')) }
        format.json { render :json => "", :status => :ok }
      else
        format.html { 
          define_company_properties
          render :action => :newshow 
        }
        format.json { render :json => @company.errors.fd_json, :status => :unprocessable_entity }
      end
    end
  end

  def sla_policies
    render :layout => false
  end

  def configure_export
    render :partial => "companies/company_export", :locals => {:csv_headers => export_customer_fields("company")}
  end

  def export_csv
    portal_url = main_portal? ? current_account.host : current_portal.portal_url
    Resque.enqueue(Workers::ExportCompany, {:csv_hash => params[:export_fields], 
                                            :user => current_user.id, 
                                            :portal_url => portal_url})
    flash[:notice] = t(:'companies.export_start')
    redirect_to :back
  end
  
  protected

    def define_company_properties 
      @total_company_tickets = 
        current_account.tickets.permissible(current_user).all_company_tickets(@company.id).visible.newest(11).preload(:ticket_states,:ticket_status,:responder,:requester)
      @company_tickets = @total_company_tickets.sort_by {|item| -item.created_at.to_i}.take(10)

      if current_account.features_included?(:archive_tickets)
        @total_company_archive_tickets = 
          current_account.archive_tickets.permissible(current_user).all_company_tickets(@company.id).newest(10).preload(:ticket_status, :responder, :requester)
        @company_archive_tickets = @total_company_archive_tickets.sort_by {|item| -item.created_at.to_i}.take(10)
      end

      company_user_list      = @company.users
      @company_users         = company_user_list.limit(6)
      @company_users_size    = company_user_list.count("1")
    end

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

    def check_domain_exists
      if @company.errors[:"company_domains.domain"].include?("has already been taken")
        @company.company_domains.each do |cd|
          @existing_company ||= current_account.company_domains.find_by_domain(cd.domain).try(:company) if cd.new_record?
        end
      end
    end
end
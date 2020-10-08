# encoding: utf-8
class CompaniesController < ApplicationController
  
  include HelpdeskControllerMethods
  include ExportCsvUtil
  include CompaniesHelperMethods
  include Redis::RedisKeys
  include Redis::OthersRedis 
  include Export::Util

  before_filter :set_selected_tab
  before_filter :redirect_old_ui_routes, only: [:index, :show, :new, :edit]
  before_filter :check_archive_feature, :only => [:component]
  before_filter :load_item,  :only => [:show, :edit, :update, :update_company, :update_notes, :sla_policies, :component]
  before_filter :build_item, :only => [:quick, :new, :create, :create_company]
  before_filter :set_required_fields, :only => [:create_company, :update_company]
  before_filter :set_validatable_custom_fields, :only => [:create, :update, :create_company, :update_company]
  before_filter :set_validatable_default_fields, only: [:create, :update, :create_company, :update_company]
  before_filter :set_native_mobile, :only => [:update]
  before_filter :export_limit_reached?, only: [:export_csv]

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
    create_export 'company'
    file_hash @data_export.id
    args = { csv_hash: params[:export_fields],
             user: current_user.id,
             portal_url: portal_url,
             data_export: @data_export.id }
    Export::CompanyWorker.perform_async(args)
    flash[:notice] = t(:'companies.export_start')
    redirect_to :back
  end

  def component
    component_type = params[:component]
    return render_error if component_type.blank?

    if component_type == 'contacts_list'
      company_user_list   = if Account.current.multiple_user_companies_enabled?
                              @company.users
                            else
                              current_account.users.company_users_via_customer_id(@company.id)
                            end
      company_users       = company_user_list.limit(Company::MAX_DISPLAY_COMPANY_CONTACTS)
      company_users_size  = company_user_list.count('1')
      render partial: "companies/contacts_list",
             locals: { company: @company, company_users: company_users,
                       company_users_size: company_users_size }
    elsif ['archive_tickets', 'recent_tickets'].include?(component_type)
      total_company_tickets = safe_send("fetch_#{component_type}")
      type                  = component_type.split('_')[0]
      company_tickets       = total_company_tickets.sort_by { |item| -item.created_at.to_i }
                                                   .take(Company::MAX_DISPLAY_COMPANY_TICKETS)
      render partial: 'companies/tickets_list',
             locals: { company: @company, company_tickets: company_tickets,
                       total_company_tickets: total_company_tickets,
                       type: type }
    end
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
      Company.es_filter(current_account.id,params[:letter], (params[:page] || 1),order_by, order_type, per_page, request.try(:uuid))
    end

    def set_selected_tab
      @selected_tab = :customers
    end

    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end

    def export_limit_reached?
      if DataExport.company_export_limit_reached?
        flash[:notice] = I18n.t('export_data.customer_export.limit_reached')
        redirect_to companies_url
      end
    end

    def after_destroy_url
      return companies_url
    end

    def check_archive_feature
      return render_403 if params[:component] == 'archive_tickets' &&
        !current_account.features_included?(:archive_tickets)
    end

    def ticket_preload
      [:ticket_states, :ticket_status, :responder, :requester]
    end

    def archive_ticket_preload
      [:ticket_status, :responder, :requester]
    end

    def fetch_recent_tickets
      current_account.tickets.permissible(current_user).all_company_tickets(@company.id)
                     .visible.newest(Company::MAX_DISPLAY_COMPANY_TICKETS + 1)
                     .preload(ticket_preload)
    end

    def fetch_archive_tickets
      current_account.archive_tickets.permissible(current_user)
                     .all_company_tickets(@company.id)
                     .newest(Company::MAX_DISPLAY_COMPANY_TICKETS + 1)
                     .preload(archive_ticket_preload)
    end

    def render_error
      render json: 'Invalid Request', status: 400
    end
end
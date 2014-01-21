# encoding: utf-8
class CustomersController < ApplicationController
  # GET /customers
  # GET /customers.xml
  
  helper ContactsHelper
  include HelpdeskControllerMethods

  before_filter :set_selected_tab
  before_filter :load_item, :only => [:show, :edit, :update, :sla_policies]
  
  def index
    per_page = (params[:per_page].blank? || params[:per_page].to_i > 50) ? 50 :  params[:per_page]
    respond_to do |format|
      format.html  do
        @customers =current_account.customers.filter(params[:letter],params[:page], per_page)
      end
     format.xml  do
        render :xml => es_scoper
      end
      format.json do
        render :json => es_scoper
      end
      
      format.atom do
        @customers =current_account.customers.filter(params[:letter],params[:page], per_page)
        @customers = @customers.newest(20)
      end
    end
  end

  # GET /customers/1
  # GET /customers/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @customer }
      format.json {render :json=> @customer.to_json}
    end
  end

  # GET /customers/new
  # GET /customers/new.xml
  def new
    @customer = current_account.customers.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @customer }
    end
  end

  # GET /customers/1/edit
  def edit
  end
  
  def quick
   if build_and_save  
      flash[:notice] = t(:'flash.general.create.success', :human_name => 'company')
   else
     flash[:notice] =  activerecord_error_list(@customer.errors)
   end
   redirect_to(customers_url)
  end

  # POST /customers
  # POST /customers.xml
  def create
    respond_to do |format|
      if build_and_save
        format.html { redirect_to(@customer, :notice => 'Company was successfully created.') }
        format.xml  { render :xml => @customer, :status => :created, :location => @customer }
        format.json  { render :json => @customer, :status => :created }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
        format.json  { render :json => @customer.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def build_and_save
    @customer = current_account.customers.new((params[:customer]))
    @customer.save
  end

  # PUT /customers/1
  # PUT /customers/1.xml
  def update

    respond_to do |format|
      if @customer.update_attributes(params[:customer])
        format.html { redirect_to(@customer, :notice => 'Company was successfully updated.') }
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
        format.json  { render :json => @customer.errors, :status => :unprocessable_entity }
      end
    end
  end

  def sla_policies
    render :layout => false
  end
  
  protected

    def scoper
      current_account.customers
    end

    def es_scoper
      order_by = (params[:order_by] == "updated_at") ? :updated_at : :name
      order_type = (params[:order_type] == "desc") ? 'desc' : 'asc'
      Customer.es_filter(current_account.id,params[:letter],(params[:page] || 1),order_by, order_type)
    end

    def set_selected_tab
        @selected_tab = :customers
    end

    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end

    def after_destroy_url
      return customers_url
    end
  
end

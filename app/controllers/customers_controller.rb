# encoding: utf-8
class CustomersController < ApplicationController # Will be Deprecated. Use CompaniesController
  # GET /customers
  # GET /customers.xml
  
  helper ContactsHelper
  include HelpdeskControllerMethods

  before_filter :set_selected_tab
  before_filter :load_item, :only => [:show, :edit, :update, :sla_policies]
  
  def index
    per_page = (!params[:per_page].blank? && params[:per_page].to_i >= 500) ? 500 :  50
    respond_to do |format|
      format.html do
        redirect_to companies_url
      end
      format.xml  do
        render :xml => es_scoper(per_page).to_xml( :root => 'customers')
      end
      format.json do
        render :json => es_scoper(per_page).to_json( :root => 'customer')
      end
    end
  end

  # GET /customers/1
  # GET /customers/1.xml
  def show
    respond_to do |format|
      format.html { redirect_to company_url(@customer) }
      format.xml  { render :xml  => @customer.to_xml(  :root => 'customer') }
      format.json { render :json => @customer.to_json( :root => 'customer') }
    end
  end

  # GET /customers/new
  # GET /customers/new.xml
  def new
    redirect_to new_company_url
  end

  # GET /customers/1/edit
  def edit
    redirect_to edit_company_url(@customer)
  end

  # POST /customers
  # POST /customers.xml
  def create
    respond_to do |format|
      if build_and_save
        format.xml  { render  :xml => @customer.to_xml(:root => 'customer'), 
                              :status => :created, :location => @customer }
        format.json  { render :json => @customer.to_json(:root => 'customer'), :status => :created }
      else
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
        format.json  { render :json => @customer.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /customers/1
  # PUT /customers/1.xml
  def update
    respond_to do |format|
      if @customer.update_attributes(params[:customer])
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
        format.json  { render :json => @customer.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy # duplicating the code from helpdesk_controller_methods for maintaining the root node returned
    @items.each do |item|
      if item.respond_to?(:deleted)
        item.update_attribute(:deleted, true)
        @restorable = true
      else
        item.destroy
      end
    end
    
    options = params[:basic].blank? ? {:basic=>true} : params[:basic].to_s.eql?("true") ? {:basic => true} : {}
    respond_to do |expects|
      expects.html do 
        process_destroy_message  
        redirect_to after_destroy_url
      end
      expects.mobile{
        render :json => {:success => true}
      }
      expects.nmobile{
        render :json => {:success => true}
      }
      expects.json  { render :json => :deleted}
      expects.js { 
        process_destroy_message
        after_destory_js 
      }
      #until we impl query based retrieve we show only limited data on deletion.
      expects.xml{ render :xml => @items.to_xml(options.merge(:root => 'customers'))}
    end
  end
  
  protected

    def scoper
      current_account.companies
    end

    def es_scoper(per_page)
      order_by = (params[:order_by] == "updated_at") ? :updated_at : :name
      order_type = (params[:order_type] == "desc") ? 'desc' : 'asc'
      Customer.es_filter(current_account.id,params[:letter],(params[:page] || 1),order_by, order_type, per_page)
    end

    def set_selected_tab
        @selected_tab = :customers
    end

    def build_and_save
      @customer = current_account.companies.new((params[:customer]))
      @customer.save
    end

    def get_domain(domains) # Possible dead code
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end

    def after_destroy_url
      return companies_url
    end
  
end

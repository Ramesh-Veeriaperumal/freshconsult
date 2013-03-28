class CustomersController < ApplicationController
  # GET /customers
  # GET /customers.xml
  
  helper ContactsHelper
  include HelpdeskControllerMethods

  before_filter :set_selected_tab
  
  def index
    respond_to do |format|
      format.html  do
        @customers =current_account.customers.filter(params[:letter],params[:page])
      end
     format.xml  do
        @customers =current_account.customers.all
        render :xml => @customers.to_xml
      end
      format.json do
        @customers =current_account.customers.all
        render :json => @customers.to_json
      end
      
      format.atom do
        @customers = @customers.newest(20)
      end
    end
  end

  # GET /customers/1
  # GET /customers/1.xml
  def show
    @customer = current_account.customers.find(params[:id])

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
    @customer = current_account.customers.find(params[:id])
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
        User.update_all("customer_id = #{@customer.id}", ['email LIKE ? and customer_id is null and account_id = ?',"%@#{get_domain(@customer.domains)}",current_account.id])
        format.html { redirect_to(@customer, :notice => 'Company was successfully created.') }
        format.xml  { render :xml => @customer, :status => :created, :location => @customer }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
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
    @customer = current_account.customers.find(params[:id])

    respond_to do |format|
      if @customer.update_attributes(params[:customer])
        format.html { redirect_to(@customer, :notice => 'Company was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @customer.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  protected

    def scoper
      current_account.customers
    end

    def set_selected_tab
        @selected_tab = :customers
    end

    def get_domain(s)
        s.gsub(/^(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') unless s.blank?
    end

    def after_destroy_url
      return customers_url
    end
  
end

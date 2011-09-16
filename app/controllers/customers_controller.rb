class CustomersController < ApplicationController
  # GET /customers
  # GET /customers.xml
  
  before_filter { |c| c.requires_permission :manage_tickets }
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

  # DELETE /customers/1
  # DELETE /customers/1.xml
  def destroy
    @customer = current_account.customers.find(params[:id])
    @customer.destroy

    respond_to do |format|
      format.html { redirect_to(customers_url) }
      format.xml  { head :ok }
    end
  end
  
  protected
  
    def set_selected_tab
      @selected_tab = :customers
  end
   def get_domain(s)
      s.gsub(/^(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'')
   end 
  
end

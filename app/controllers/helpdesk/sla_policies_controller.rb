class Helpdesk::SlaPoliciesController < Admin::AdminController
  
  before_filter :only => [:new, :create] do |c|
    c.requires_feature :customer_slas
  end
   
  def index
    
     @sla_policies = current_account.sla_policies.all
      respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @sla_policies }
    end
    
  end

  def show
    
     @sla_policy = current_account.sla_policies.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @sla_policy }
    end
    
  end

  def new
    
     @sla_policy = current_account.sla_policies.new      
     4.times {@sla_policy.sla_details.build} 
      respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @sla_policy }
    end
    
  end

  def edit
    
     @sla_policy = current_account.sla_policies.find(params[:id], :include =>:sla_details , :order =>'helpdesk_sla_details.priority DESC')     
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @sla_policy }
    end
    
  end

  def create
    
    @sla_policy = current_account.sla_policies.new(params[nscname])    
    params[:SlaDetails].each_value { |sla| @sla_policy.sla_details.build(sla) }
    
    if @sla_policy.save
        flash[:notice] = "Sla Policy has been created."
        redirect_to :action => 'index'
    else
      flash[:notice] = "Unable to save Sla Policy"
       render :action => 'new'
    end  
  end

  def update    
    
    @sla_policy = current_account.sla_policies.find(params[:id])
    respond_to do |format|      
      if @sla_policy.update_attributes(params[nscname])
         params[:SlaDetails].each_value do |sla|           
         @sla_detail = Helpdesk::SlaDetail.find(sla[:id])
         @sla_detail.update_attributes(sla)
       end
        format.html { redirect_to(helpdesk_sla_policies_url, :notice => 'Sla policy was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @sla_policy.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def destroy
    
    @sla_policy = current_account.sla_policies.find(params[:id])
    @sla_policy.destroy
    respond_to do |format|
      format.html { redirect_to(helpdesk_sla_policies_url) }
      format.xml  { head :ok }
    end
    
  end
  
  protected

  def scoper
    eval "Helpdesk::#{cname.classify}"
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
end

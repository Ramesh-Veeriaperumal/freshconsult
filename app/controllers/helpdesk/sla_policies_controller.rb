class Helpdesk::SlaPoliciesController < Admin::AdminController
 
  include Helpdesk::ReorderUtility
  before_filter :only => [:new, :create] do |c|
    c.requires_feature :customer_slas
  end
  before_filter :load_sla_policy, :only => [ :update, :destroy, :activate ]
  before_filter :initialize_escalation_level_details, :only => [:edit]
   
  def index
    @sla_policies = scoper
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @sla_policies }
    end    
  end

  def new
    @sla_policy = scoper.new
    4.times { @sla_policy.sla_details.build }

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @sla_policy }
    end
  end

  def edit
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @sla_policy }
    end
  end

  def create
    @sla_policy = scoper.new(params[nscname])
    params[:SlaDetails].each_value {|sla|  @sla_policy.sla_details.build(sla) }   
    if @sla_policy.save
        flash[:notice] = t(:'flash.general.create.success', :human_name => "SLA Policy")
        flash[:highlight] = dom_id(@sla_policy)
        redirect_to :action => 'index'
    else
      flash[:notice] = t(:'flash.general.create.failure', :human_name => "SLA Policy")
      render :action => 'new'
    end
  end

  def update    
    respond_to do |format|
      if @sla_policy.update_attributes(params[nscname])
        params[:SlaDetails].each_value do |sla|           
          @sla_detail = @sla_policy.sla_details.find(sla[:id])
          @sla_detail.update_attributes(sla)
        end

        format.html { 
          flash[:highlight] = dom_id(@sla_policy)
          flash[:notice] = t(:'flash.general.update.success', :human_name => "SLA Policy")
          redirect_to :action => 'index'}
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @sla_policy.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def destroy
    @sla_policy.destroy
    respond_to do |format|
      format.html { 
        flash[:notice] = t(:'flash.general.destroy.success', :human_name => "SLA Policy")
        redirect_to(helpdesk_sla_policies_url) }
      format.xml  { head :ok }
    end
    
  end

  def activate
    if @sla_policy.can_be_activated? && 
        @sla_policy.update_attributes({:active => params[nscname][:active]})
      
      type = params[nscname][:active] == "true" ? 'activation' : 'deactivation'
      
      flash[:highlight] = dom_id(@sla_policy)
      flash[:notice] = t("flash.general.#{type}.success", :human_name => "SLA Policy")
      redirect_to :action => 'index'
      # format.json {render :json => {:head => :ok}}
    else
      flash[:notice] = t(:'flash.general.activation.failure', :human_name => "SLA Policy")
      redirect_to :action => 'index'
      # format.json {render :json => {:status => :unprocessable_entity}}
    end
  end
  
  protected

    def scoper
      current_account.sla_policies
    end

    def cname
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end
    
    def reorder_scoper
      scoper.active
    end
    
    def reorder_redirect_url
      helpdesk_sla_policies_path
    end

    def load_sla_policy
      @sla_policy = scoper.find(params[:id])
    end

    def initialize_escalation_level_details
      @sla_policy = scoper.find(params[:id], :include =>:sla_details) 

      @companies = current_account.customers.find(:all, 
            :conditions => ["id in (?)", @sla_policy.conditions[:company_id]]).map {|company| 
            [company.name, company.id]} unless (@sla_policy.is_default || 
                                                @sla_policy.conditions[:company_id].blank?)
      
      return if @sla_policy.escalations.blank?

      fetch_time_and_agents_list
      fetch_agents
    end

    def fetch_time_and_agents_list
      @agents_id = []
      @esc_agents = {}
      @time = {}
      Helpdesk::SlaPolicy::ESCALATION_TYPES.each do |type|   
        next if @sla_policy.escalations[type].blank?

        @sla_policy.escalations[type].each_pair do |k,v|
          @time["#{type}_#{k}"] = v[:time]
          @agents_id += v[:agents_id]
          @esc_agents["#{type}_#{k}"] = ActiveSupport::JSON.encode(v[:agents_id])
        end
      end
    end

    def fetch_agents
      unless @agents_id.blank? 
        @agents_cache = {}
        @agents_id.uniq!
        current_account.users.technicians.visible.find(:all, :conditions => ["id in (?)", @agents_id], 
                        :select => "id, name, email").each{|agent| 
                        @agents_cache[agent.id] = {:name => agent.name, :email => agent.email}}
      end
    end
  
end

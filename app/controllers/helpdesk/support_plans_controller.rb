class Helpdesk::SupportPlansController < ApplicationController
  
  
  def index
    
    logger.debug "Here is my Support Plan Controller"
    
     @support_plans = Helpdesk::SupportPlan.all
    
    #@sla_detail = Helpdesk::SlaDetail.new
    
    print "sla details"
    
    print @support_plans

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @support_plans }
    end
  end

  def show
    
     @support_plan = Helpdesk::SupportPlan.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @support_plan }
    end
  end

  def new
    
     #@project = Project.new
  #5.times { @project.tasks.build }
    
     @support_plan = Helpdesk::SupportPlan.new 
     
     4.times {@support_plan.sla_details.build}
     
     

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @support_plan }
    end
  end

  def edit
    @support_plan = Helpdesk::SupportPlan.find(params[:id]) 
    
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @support_plan }
    end
  end

  def create
    
    
    @support_plan = Helpdesk::SupportPlan.new(params[nscname])
    
    params[:SlaDetails].each_value { |sla| @support_plan.sla_details.build(sla) }
  if @support_plan.save
    redirect_to :action => 'index'
  else
    render :action => 'new'
  end
    
      #@support_plan = Helpdesk::SupportPlan.new(params[nscname])    
     
    #respond_to do |format|
     # if @support_plan.save
      #  format.html { redirect_to(@support_plan, :notice => 'Helpdesk::SupportPlan was successfully created.') }
       # format.xml  { render :xml => @support_plan, :status => :created, :location => @support_plan }
      #else
       # format.html { render :action => "new" }
        #format.xml  { render :xml => @sla_detail.errors, :status => :unprocessable_entity }
      #end
    #end
  end

  def update
    
    @support_plan = Helpdesk::SupportPlan.find(params[:id])

    respond_to do |format|      
      if @support_plan.update_attributes(params[nscname])
        params[:SlaDetails].each_value do |sla| 
          logger.debug "here is the sla #{sla}"
          @sla_detail = Helpdesk::SlaDetail.find(sla[:id])
          @sla_detail.update_attributes(sla)
          end
        
        #@support_plan.sla_details.update_attributes(params[:SlaDetails])
        format.html { redirect_to(helpdesk_support_plans_url, :notice => 'Helpdesk::SupportPlan was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @support_plan.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def destroy
    
    @support_plan = Helpdesk::SupportPlan.find(params[:id])
    @support_plan.destroy

    respond_to do |format|
      format.html { redirect_to(helpdesk_support_plans_url) }
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

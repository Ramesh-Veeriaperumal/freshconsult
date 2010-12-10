class Helpdesk::SlaDetailsController < ApplicationController
  # GET /helpdesk_sla_details
  # GET /helpdesk_sla_details.xml
  def index
    
    
    @helpdesk_sla_details = Helpdesk::SlaDetail.all
    
    #@sla_detail = Helpdesk::SlaDetail.new
    
    print "sla details"
    
    print @helpdesk_sla_details

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @helpdesk_sla_details }
    end
  end

  # GET /helpdesk_sla_details/1
  # GET /helpdesk_sla_details/1.xml
  def show
    @sla_detail = Helpdesk::SlaDetail.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @sla_detail }
    end
  end

  # GET /helpdesk_sla_details/new
  # GET /helpdesk_sla_details/new.xml
  def new
    @sla_detail = Helpdesk::SlaDetail.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @sla_detail }
    end
  end

  # GET /helpdesk_sla_details/1/edit
  def edit
    @sla_detail = Helpdesk::SlaDetail.find(params[:id])
  end

  # POST /helpdesk_sla_details
  # POST /helpdesk_sla_details.xml
  def create
    
    print "here is the params"
    
    puts params[nscname]
    
    @sla_detail = Helpdesk::SlaDetail.new(params[nscname])
    
     
    respond_to do |format|
      if @sla_detail.save
        format.html { redirect_to(@sla_detail, :notice => 'Helpdesk::SlaDetail was successfully created.') }
        format.xml  { render :xml => @sla_detail, :status => :created, :location => @sla_detail }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @sla_detail.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /helpdesk_sla_details/1
  # PUT /helpdesk_sla_details/1.xml
  def update
    puts "update is called"
    
   
    puts "id is ::"
    print params[nscname][:id]
    
    @sla_detail = Helpdesk::SlaDetail.find(params[nscname][:id])

    respond_to do |format|      
      if @sla_detail.update_attributes(params[nscname])
        format.html { redirect_to(helpdesk_sla_details_url, :notice => 'Helpdesk::SlaDetail was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @sla_detail.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /helpdesk_sla_details/1
  # DELETE /helpdesk_sla_details/1.xml
  def destroy
    @sla_detail = Helpdesk::SlaDetail.find(params[:id])
    @sla_detail.destroy

    respond_to do |format|
      format.html { redirect_to(helpdesk_sla_details_url) }
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

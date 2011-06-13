class Admin::CannedResponsesController < Admin::AdminController 
   #can give this feature only to hire end plans
  #before_filter { |c| c.requires_feature :canned_response }
  
  
  def index
    @ca_responses = scoper.find(:all)
  end

  def show
   redirect_to edit_admin_canned_response_url
  end

  def new
    @ca_response = scoper.new  
    @ca_response.accessible = current_account.user_accesses.new
    @ca_response.accessible.visibility = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    respond_to do |format|
      format.html
      format.xml  { render :xml => @ca_response }
    end
  end

  def edit
    @ca_response = scoper.find(params[:id])  
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @ca_response }
    end
  end
  
  def create    
    @ca_response = scoper.new(params[nscname])   
    respond_to do |format|
      if @ca_response.save        
        format.html {redirect_to(admin_canned_responses_url, :notice => 'Canned Response was successfully created.') }        
        format.xml  { render :xml => @ca_response, :status => :created, :location => @ca_response }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
   @ca_response = scoper.find(params[:id])    
   respond_to do |format|     
       if @ca_response.update_attributes(params[nscname])            
          format.html {redirect_to(admin_canned_responses_url, :notice => 'Canned Response was successfully updated.') } 
          format.xml  { render :xml => @ca_response, :status => :updated, :location => @ca_response }     
       else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
       end
    end
  end

  def destroy
    @ca_response = scoper.find(params[:id])    
    @ca_response.destroy
    respond_to do |format|
      format.html { redirect_to(admin_canned_responses_url ,:notice => 'Canned Response has been deleted successfully.') }
      format.xml  { head :ok }
    end
  end

private

 def scoper
   current_account.canned_responses
 end
 
  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end 
   
  
end

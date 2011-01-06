class AgentsController < ApplicationController
  def index
    
    @agents = Agent.find(:all , :joins => :user)
  

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @agents }
    end
  end

  def show
  end

  def new
    
    @agent = Agent.new
    
    @agent.user = User.new
    
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end
    
  end

  def edit
  end

  def create
    
  #@agent = Agent.new(params[nscname])
  
  #@user = User.new(params[:user])
  @user = User.new(params[:user])
  
    
    @agent = @user.agents.new(params[nscname])
    #params[:user].each_value { |sla| @sla_policy.sla_details.build(sla) }
  #@agent.user= User.new(params[:user])
  logger.debug "here is the element inspect:: #{@agent.inspect}"
  respond_to do |format|
  if @agent.save
    redirect_to :action => 'index'
  else
    logger.debug "The error msg is #{@agent.errors.inspect}"
    
    format.html { render :action => "new" }
    format.xml  { render :xml => @agent.errors, :status => :unprocessable_entity }
  end
  
   end
  
    
     
   
  end

  def update
  end

  def destroy
end

 protected

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end

end

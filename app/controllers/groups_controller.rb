class GroupsController < ApplicationController
  def index
    
      @groups = Group.all
  

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
    
  end

  def show
     @group = Group.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  def new
    
    @group = Group.new
    
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
    
    
  end

  def edit
    
     @group = Group.find(params[:id]) 
    
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @group }
    end
    
  end

  def create
     @group = Group.new(params[nscname])
     
  if @group.save
    redirect_to :action => 'index'
  else
    render :action => 'new'
  end
  end

  def update
    
     @group = Group.find(params[:id])

    respond_to do |format|      
      if @group.update_attributes(params[nscname])
       
        format.html { redirect_to(groups_url, :notice => 'Group was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => Group.errors, :status => :unprocessable_entity }
      end
    end
    
  end

  def destroy
    
      @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
    
  end
protected

  

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
end

module ModelControllerMethods
  def self.included(base)
    base.send :before_filter, :build_object, :only => [ :new, :create ]
    base.send :before_filter, :load_object, :only => [ :show, :edit, :update, :destroy , :restore , :make_agent]
  end
  
  def index
    @users = self.instance_variable_set('@' + self.controller_name,
      scoper.find(:all, :order => 'name'))      

    respond_to do |format|
      format.html  do
        @users = @users.paginate(
          :page => params[:page], 
          :order => 'name',
          :per_page => 10)
      end
      format.atom do
        @users = @users.newest(20)
      end
    end
  end
  
  def create
    if @obj.save
      flash[:notice] = create_flash
     
      respond_to do |format|
      format.html  do
         redirect_back_or_default redirect_url
      end
      format.xml do
        render :xml => @obj 
      end
    end
    else
      create_error
      render :action => 'new'
    end
  end

  def update
    if @obj.update_attributes(params[cname])      
      
      respond_to do |format|        
        format.html  do
          flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
          redirect_back_or_default redirect_url
        end
        format.json do                    
          render :json => {:updated => true}.to_json
        end
      end
      
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      update_error
      render :action => 'edit'
    end
  end
  
  def destroy
    @result = @obj.destroy
    respond_to do |wants|
      wants.html do
        if @result
          flash[:notice] = I18n.t(:'flash.general.destroy.success', :human_name => human_name)
          redirect_back_or_default redirect_url
        else
          render :action => 'show'
        end
      end
      
      wants.js do
        render :update do |page|
          if @result
            page.remove "#{@cname}_#{@obj.id}"
          else
            page.alert "Errors deleting #{@obj.class.to_s.downcase}: #{@obj.errors.full_messages.to_sentence}"
          end
        end
      end
    end
  end
  
  protected
  
    def cname
      @cname ||= controller_name.singularize
    end
    
    def human_name
      cname.humanize.downcase
    end
    
    def set_object
      @obj ||= self.instance_variable_get('@' + cname)
    end
    
    def load_object
      @obj = self.instance_variable_set('@' + cname,  scoper.find(params[:id]))
    end
    
    def build_object
      
      @obj = self.instance_variable_set('@' + cname,
        scoper.is_a?(Class) ? scoper.new(params[cname]) : scoper.build(params[cname]))
    end
    
    def scoper
      Object.const_get(cname.classify)
    end
    
    def redirect_url
      { :action => 'index' }
    end
  
    def create_flash
      I18n.t(:'flash.general.create.success', :human_name => human_name)
    end
    
    def create_error
    end
    
    def update_error
    end
end

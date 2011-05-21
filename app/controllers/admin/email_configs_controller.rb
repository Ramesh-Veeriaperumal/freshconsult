class Admin::EmailConfigsController < Admin::AdminController
  include ModelControllerMethods
  
  before_filter :only => [:new, :create] do |c|
    c.requires_feature :multi_product
  end
   
  def index
    @email_configs = scoper.find(:all, :order => 'primary_role desc, id')
    @groups = current_account.groups    
  end
  
  def new
    @email_configs = scoper.all
    @groups = current_account.groups 
  end

  def edit
    @email_configs = scoper.all
    @groups = current_account.groups
  end
  
  def make_primary 
    @email_config = scoper.find(params[:id])
    if @email_config
      current_account.primary_email_config.update_attributes(:primary_role => false)
      if @email_config.update_attributes(:primary_role => true)
        flash[:notice] = "<b>#{@email_config.reply_email}</b> is now your primary support email!"
        redirect_back_or_default redirect_url
      end
    end
  end
  
  def register_email
    @email_config = scoper.find_by_activator_token params[:activation_code]
    if @email_config
      unless @email_config.active
        @email_config.active = true
        flash[:notice] = "#{@email_config.reply_email} has been activated!" if @email_config.save
      else
        flash[:warning] = "#{@email_config.reply_email} has been activated already!"
      end
    else
      flash[:warning] = "The activation code is not valid!"
    end
    
    redirect_back_or_default redirect_url
  end
  
  def deliver_verification
    @email_config = scoper.find(params[:id])
    @email_config.deliver_verification_email
    flash[:notice] = "Verification email has been sent to #{@email_config.reply_email}!"
    redirect_back_or_default redirect_url
  end
  
  protected
    def scoper
      current_account.all_email_configs
    end
 
    def human_name
      "email"
    end
  
    def create_flash
      "The #{human_name} has been added."
    end
    
    def create_error #Need to refactor this code, after changing helpcard a bit.
      @email_configs = scoper.all
      @groups = current_account.groups
    end
    
    def update_error
      @email_configs = scoper.all
      @groups = current_account.groups
    end    
end

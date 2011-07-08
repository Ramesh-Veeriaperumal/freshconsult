class Admin::EmailConfigsController < Admin::AdminController
  include ModelControllerMethods
  
  before_filter :only => [:new, :create] do |c|
    c.requires_feature :multi_product
  end
   
  def index
    @email_config = current_account.primary_email_config
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
        flash[:notice] = t(:'flash.email_settings.make_primary.success', 
            :reply_email => @email_config.reply_email)
        redirect_back_or_default redirect_url
      end
    end
  end
  
  def register_email
    @email_config = scoper.find_by_activator_token params[:activation_code]
    if @email_config
      unless @email_config.active
        @email_config.active = true
        flash[:notice] = t(:'flash.email_settings.activation.success', 
            :reply_email => @email_config.reply_email) if @email_config.save
      else
        flash[:warning] = t(:'flash.email_settings.activation.already_activated', 
            :reply_email => @email_config.reply_email)
      end
    else
      flash[:warning] = t(:'flash.email_settings.activation.invalid_code')
    end
    
    redirect_back_or_default redirect_url
  end
  
  def deliver_verification
    @email_config = scoper.find(params[:id])
    @email_config.deliver_verification_email
    flash[:notice] = t(:'flash.email_settings.send_activation.success', 
        :reply_email => @email_config.reply_email)
    redirect_to :back
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

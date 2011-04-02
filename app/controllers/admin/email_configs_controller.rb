class Admin::EmailConfigsController < Admin::AdminController
  include ModelControllerMethods
   
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
  
  protected
    def scoper
      current_account.email_configs
    end
 
    def human_name
      "email"
    end
  
    def create_flash
      "The #{human_name} has been added."
    end
    
end

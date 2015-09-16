class Admin::EmailCommandsSettingsController < Admin::AdminController

  def index
    @email_commands_setting = current_account.account_additional_settings

    @email_content_commands = '"status":"pending", "priority":"medium", "agent":"John Robert"'
    
    delimeter = current_account.email_cmds_delimeter
    
    content_prefix = "Hi,\n\n";
    content_suffix = "\n\nYour issue is resolved now.\n\nThanks,\nAgent Name.\n"; 
    @content = "#{content_prefix}#{delimeter} #{@email_content_commands} #{delimeter}#{content_suffix}"

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @email_commands_setting }
    end
  end

  def update
    @email_commands_setting = current_account.account_additional_settings

    if @email_commands_setting.update_attributes(params[:account_additional_settings])     
      flash[:notice] = I18n.t('email_commands_update_success')    
    else
      flash[:notice] = I18n.t('email_commands_update_failed')+(@email_commands_setting.errors.messages[:email_cmds_delimeter].first || "")
    end
    redirect_back_or_default :action => 'index'
  end

end

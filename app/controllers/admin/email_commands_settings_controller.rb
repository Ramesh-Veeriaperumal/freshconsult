class Admin::EmailCommandsSettingsController < Admin::AdminController

  def index
    @email_commands_setting = current_account.email_commands_setting

    @email_content_commands = "status:pending, priority:medium, agent:John Robert"
    
    delimeter = current_account.email_commands_setting.email_cmds_delimeter

    @email_content_custom_commands = ""
    current_account.ticket_fields.custom_fields.each do |field|
      @email_content_custom_commands += "#{field.label}: [Custom Field Value] <br>"
    end

    
    content_prefix = "Hi,\n\n";
    content_suffix = "\n\nYour issue is resolved now.\n\nThanks,\nAgent Name.\n"; 
    @content = "#{content_prefix}#{delimeter} #{@email_content_commands} #{delimeter}#{content_suffix}"

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @email_commands_setting }
    end
  end

  def update
    @email_commands_setting = current_account.email_commands_setting

   if @email_commands_setting.update_attributes(params[:email_commands_setting])     
     flash[:notice] = I18n.t('email_commands_update_success')    
   else
     flash[:notice] = I18n.t('email_commands_update_failed')
   end

   redirect_back_or_default :action => 'index'
  
  end
end

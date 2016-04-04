class Admin::AccountAdditionalSettingsController < Admin::AdminController

  def update
    @account_additional_settings = current_account.account_additional_settings

    if @account_additional_settings.update_attributes(params[:account_additional_settings])     
      flash[:notice] = I18n.t('bcc_email_updated_success_msg')    
    else
      flash[:notice] = I18n.t('bcc_email_updated_failure_msg')
    end

    redirect_back_or_default '/admin/email_configs'
  end

  def assign_bcc_email
    @account_additional_settings = current_account.account_additional_settings
    render :partial => "bcc_email"
  end

  def update_font
    unless params["font-family"].blank?
      @account_additional_settings = current_account.account_additional_settings
      @account_additional_settings.font_settings = {"font-family" => params["font-family"]}
    end
    
    respond_to do |format|
      format.html
      format.js { 
       render :partial => '/admin/email_notifications/fontsettings', :formats => [:rjs]
      }
    end
  end
end

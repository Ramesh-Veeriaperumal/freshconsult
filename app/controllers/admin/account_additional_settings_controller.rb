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
end

class UserEmailsController < ApplicationController

  before_filter :require_user

  def make_primary
    @user = current_account.users.find(params[:id])
    if @user.reset_primary_email(params[:email_id])
      flash[:notice] = t('merge_contacts.primary_changed')
    else
      flash[:error] = t('merge_contacts.failed_change')
    end
    render :update do |page| page.reload end
  end

  def send_verification
    @user_mail = current_account.user_emails.find(params[:email_id])
    @user_mail.deliver_contact_activation_email
    flash[:notice] = t('merge_contacts.activation_sent')
    render :update do |page| show_ajax_flash page end
  end

end
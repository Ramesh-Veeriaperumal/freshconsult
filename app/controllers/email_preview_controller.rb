class EmailPreviewController < ApplicationController

  include LiquidSyntaxParser

  before_filter :validate_active_user
  before_filter :validate_preview_liquid, :only => :generate_preview

  MAX_MAIL_CONTENT_SIZE = 60000

  def generate_preview
    if @errors.present?
      flash_msg = @errors.uniq.join("<br>")
      render :json => { :success => false, :msg => flash_msg }
    else
      body, subject = parse_preview(params[:notification_body], params[:subject])
      render :json => { :success => true, :preview => body, :subject => subject}
    end
  end

  def send_test_email
    subject     = Helpdesk::HTMLSanitizer.clean(params[:subject].to_s)
    mail_body   = Helpdesk::HTMLSanitizer.clean(params[:mail_body].to_s)
    # Exception handling: To avoid any exception in sending mail via delayed jobs, as it will exceed the size of the column.
    if (mail_body + subject).length > MAX_MAIL_CONTENT_SIZE
      render :json => { :success => false, :msg => I18n.t('email_notifications.preview_message_too_large') }
    else
      EmailPreviewMailer.send_later(:send_test_email, mail_body, subject, current_user.email, locale_object: current_user)
      render :json => { :success => true, :message => I18n.t('email_notifications.preview_mail_sent', :email => User.current.email) }
    end
    
  end

  private

  def validate_active_user
    unless current_account.verified? && current_user.active?
      render :json => {access_denied: true}
      return false
    end
  end

  def validate_preview_liquid
    syntax_rescue(params[:notification_body])
    syntax_rescue(params[:subject])
  end

  def parse_preview(notification_body, subject)
    preview_object = NotificationPreview.new(current_account, current_user)
    [preview_object.notification_preview(notification_body), preview_object.notification_preview(subject)]
  end

end
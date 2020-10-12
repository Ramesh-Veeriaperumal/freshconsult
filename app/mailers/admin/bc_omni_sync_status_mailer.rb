class Admin::BcOmniSyncStatusMailer < ActionMailer::Base

  layout 'email_font'
  include EmailHelper

  def send_sync_status_email(user, business_calendar, action)
    @user_name = user.name
    @action = action
    @business_calendar = business_calendar
    @business_calendar_url = business_calendar.mint_url
    subject ||= I18n.t('mailer_notifier_subject.send_sync_status_email', action: action)
    @headers = {
        from:    Account.current.default_friendly_email,
        to:      user.email,
        subject: subject,
        sent_on: Time.zone.now
    }
    mail(@headers) do |part|
      part.text { render 'admin/business_calendars/mailer/bc_omni_sync_status.text.plain.erb' }
      part.html { render 'admin/business_calendars/mailer/bc_omni_sync_status.text.html.erb' }
    end.deliver
  end
  include MailerDeliverAlias
end
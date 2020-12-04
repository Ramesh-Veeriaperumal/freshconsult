# frozen_string_literal: true

class Admin::ConsultationNotificationMailer < ActionMailer::Base
  layout 'email_font'
  include EmailHelper

  def send_reminder_notification_email(user, appointment, meeting_url)
    @user_name = user.name
    @appointment = appointment
    @meeting_url = meeting_url
    subject ||= I18n.t('mailer_notifier_subject.consultation_reminder')
    @headers = {
      from: Account.current.default_friendly_email,
      to: user.email,
      subject: subject,
      sent_on: Time.zone.now
    }
    mail(@headers) do |part|
      part.text { render 'admin/consultation_management/consultation_reminder.text.plain.erb' }
      part.html { render 'admin/consultation_management/consultation_reminder.text.html.erb' }
    end.deliver
  end
end
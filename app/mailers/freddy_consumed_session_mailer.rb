# frozen_string_literal: true

class FreddyConsumedSessionMailer < ActionMailer::Base
  def send_consumed_session_remainder(to_emails, sessions_consumed, sessions_count)
    @other_emails = to_emails[:other]
    @headers = {
      to: to_emails[:group],
      from: AppConfig['from_email'],
      subject: t('freddy_consumed_session_mailer.consumed_sessions_subject', sessions_consumed: sessions_consumed),
      sent_on: Time.zone.now
    }
    mail(@headers) do |part|
      part.text { render '/freddy_sessions/consumed_session_remainder.text.plain.erb', mail_body_locales(sessions_consumed, sessions_count) }
      part.html { render '/freddy_sessions/consumed_session_remainder.text.html.erb', mail_body_locales(sessions_consumed, sessions_count) }
    end.deliver
  end

  def mail_body_locales(sessions_consumed, sessions_count)
    {
      locals: {
        account: Account.current,
        sessions_consumed: sessions_consumed,
        session_count: sessions_count
      }
    }
  end
end

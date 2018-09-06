class Admin::LanguageMailer < ActionMailer::Base
  include EmailHelper

  def primary_language_change(email, language)
    headers = {
      to: [email, 'fd-self-service-aor@freshworks.com'],
      from: AppConfig['from_email'],
      subject: "#{Rails.env} :: #{PodConfig['CURRENT_POD']} :: Primary language changed",
      sent_on: Time.zone.now
    }
    mail(headers) do |part|
    part.html { render 'primary_language_change', locals: { account_id: Account.current.id, language: language} }
    end.deliver
  end
end

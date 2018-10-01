class Admin::LanguageMailer < ActionMailer::Base
  include EmailHelper

  def primary_language_change(email, language)
    headers = {
      to: [email, 'fd-self-service-aor@freshworks.com'],
      from: AppConfig['from_email'],
      subject: "Primary language change :: Account #{Account.current.id} :: #{Rails.env} :: #{PodConfig['CURRENT_POD']}",
      sent_on: Time.zone.now
    }
    mail(headers) do |part|
    part.html { render 'primary_language_change', locals: { account_id: Account.current.id, account_domain: Account.current.full_domain, language: language} }
    end.deliver
  end
end

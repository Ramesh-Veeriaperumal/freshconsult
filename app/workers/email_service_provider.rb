class EmailServiceProvider
  include Sidekiq::Worker
  include Admin::EmailConfig::EmailProvider

  sidekiq_options :queue => :email_service_provider, :retry => 0, :failures => :exhausted

  def perform
    account = Account.current
    mail_address = Mail::Address.new(account.admin_email)
    account.account_configuration.company_info[:email_service_provider] = get_email_service_name(mail_address.domain)
    account.account_configuration.save
  end
end

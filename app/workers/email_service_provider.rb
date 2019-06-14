require 'resolv'
class EmailServiceProvider
  include Sidekiq::Worker
  sidekiq_options :queue => :email_service_provider, :retry => 0, :failures => :exhausted
  TIMEOUT = 10.seconds
  EMAIL_SERVICE_PROVIDER_MAPPING = {
      'hotmail' => 'outlook',
      'googlemail' => 'google',
      'yahoodns' => 'yahoo'
  }.freeze

  def perform
    account = Account.current
    mail_address = Mail::Address.new(account.admin_email)
    account.account_configuration.company_info[:email_service_provider] = get_email_service_name(mail_address.domain)
    account.account_configuration.save
  end

  private

  def get_email_service_name(domain)
    Timeout.timeout(TIMEOUT) do
      mxrecords = Resolv::DNS.open do |dns|
        resources = dns.getresources(domain, Resolv::DNS::Resource::IN::MX) # This will return mx records
        resources.map { |r| [r.exchange.to_s.downcase, r.preference] }
      end
      return if mxrecords.empty?
      mxrecords.sort { |a, b| a[1] <=> b[1] } # Sorting mx records with preference to store the first preference in DB
      email_service_name = (mxrecords[0][0] || '').split('.')[-2]
      EMAIL_SERVICE_PROVIDER_MAPPING.try(:[], email_service_name) || email_service_name
    end
  rescue => e
    Rails.logger.info "Error message for email service provider, Account id : #{Account.current.id}\n#{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end

end

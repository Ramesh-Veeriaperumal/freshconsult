require 'resolv'
module Admin::EmailConfig::EmailProvider
  include Email::Mailbox::Constants

  def get_email_service_name(domain)
    Timeout.timeout(EMAIL_PROVIDER_TIMEOUT) do
      mxrecords = Resolv::DNS.open do |dns|
        resources = dns.getresources(domain, Resolv::DNS::Resource::IN::MX) # This will return mx records
        resources.map { |r| [r.exchange.to_s.downcase, r.preference] }
      end
      return if mxrecords.empty?

      mxrecords.sort_by { |a| a[1] } # Sorting mx records with preference to store the first preference in DB
      email_service_name = (mxrecords[0][0] || '').split('.')[-2]
      EMAIL_SERVICE_PROVIDER_MAPPING.try(:[], email_service_name) || email_service_name
    end
  rescue StandardError => e
    Rails.logger.info "Error message for email service provider, Account id : #{Account.current.id}\n#{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end
end

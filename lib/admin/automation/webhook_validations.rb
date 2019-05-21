module Admin::Automation::WebhookValidations
  include Redis::OthersRedis
  include Cache::LocalCache

  # BLACKLIST_IPS = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', '169.254.0.0/16', 'fe80::/10', '127.0.0.0/8'].freeze # "ffx1::/16"
  ALLOWED_PROTOCOLS = ['https', 'http'].freeze

  def valid_webhook_url?(url)
    is_valid = true
    begin
      url = URI.parse(url)
      is_valid = !(ALLOWED_PROTOCOLS.exclude?(url.scheme) || blacklist_domain?(url.host) || blacklist_ips?(url.host))
    rescue StandardError => error
      Rails.logger.debug "Error in Admin::Automation::ValidateWebhook... #{error.message}"
      is_valid = false
    end
    is_valid
  end

  def blacklist_ips()
    fetch_lcached_set(WEBHOOK_BLACKLIST_IP, 5.minutes)
  end

  def blacklist_domain()
    fetch_lcached_set(WEBHOOK_BLACKLIST_DOMAIN, 5.minutes)
  end

  def blacklist_domain?(domain)
    blacklist_domain.include?(domain)
  end

  def blacklist_ips?(domain)
    domain_ip = Resolv.getaddress(domain)
    blacklist_ips.each do |subnet|
      subnet_ips = IPAddr.new(subnet)
      return true if subnet_ips.include?(IPAddr.new(domain_ip))
    end
    false
  end
end

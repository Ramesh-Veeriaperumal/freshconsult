module CustomDomain
  class CnameValidator
    include Dnsruby

    DNS_QUERY_TIMEOUT_SECS = 2

    def initialize(domain, valid_fd_domains)
      @domain = domain
      @valid_fd_domains = valid_fd_domains
    end

    def allow?
      cname_mapping_present
    end

    private

      def cname_mapping_present()
        dns_response = retrieve_dns_records(@domain)
        return false unless dns_response.present?
        dns_response.any? { |dns_rec| @valid_fd_domains.include?(dns_rec.cname.to_s.chomp('.')) }
      end

      def retrieve_dns_records(domain)
        dns = Dnsruby::Resolver.new(do_caching: false, query_timeout: DNS_QUERY_TIMEOUT_SECS)
        dns.query(domain, Types.CNAME).answer
      rescue Dnsruby::NXDomain
        Rails.logger.debug("Domain [#{domain}] does not exist")
        []
      rescue => e
        Rails.logger.debug("Exception querying dns records #{e.message} #{e.backtrace.join("\n")}")
        []
      end
  end
end

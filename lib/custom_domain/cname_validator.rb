module CustomDomain
  class CnameValidator
    include Dnsruby

    DNS_QUERY_TIMEOUT_SECS = 2
    FDKEY_PREFIX = 'fdkey.'

    def initialize(domain, valid_fd_domains, verification_hash)
      @domain = domain
      @valid_fd_domains = valid_fd_domains
      @verification_hash = verification_hash
    end

    def mapping_error
      return 'flash.portal.update.invalid_cname' unless cname_mapping_present
      return 'flash.portal.update.invalid_hash_mapping' unless hash_mapping_present
    end

    private

      def cname_mapping_present()
        dns_response = retrieve_dns_records(@domain, Types.CNAME)
        return false unless dns_response.present?
        dns_response.any? { |dns_rec| @valid_fd_domains.include?(dns_rec.cname.to_s.chomp('.')) }
      end

      def hash_mapping_present
        dns_response = retrieve_dns_records(FDKEY_PREFIX + @domain, Types.TXT)
        return false unless dns_response.present?
        dns_response.any? { |dns_rec| dns_rec.rdata.to_s.include?(@verification_hash) }
      end

      def retrieve_dns_records(domain, type)
        dns = Dnsruby::Resolver.new(do_caching: false, query_timeout: DNS_QUERY_TIMEOUT_SECS)
        dns.query(domain, type).answer
      rescue Dnsruby::NXDomain
        Rails.logger.debug("Domain [#{domain}] does not exist")
        []
      rescue => e
        Rails.logger.debug("Exception querying dns records #{e.message} #{e.backtrace.join("\n")}")
        []
      end
  end
end

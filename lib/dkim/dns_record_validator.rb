class Dkim::DnsRecordValidator
  
  include Dnsruby
  
  attr_accessor :domain_category, :current_account

  def initialize(domain_category)
    @domain_category = domain_category
  end
  
  def check_records
    dkim_records = domain_category.dkim_records.customer_records
    dkim_records.each do |dkim_record|
      dkim_record.status = (validate(dkim_record) ? true : false)
      dkim_record.save if dkim_record.changes.present?
    end
    dkim_records.non_active_records.count.zero? # to ensure all are active
  rescue Exception => e
    Rails.logger.debug("*************** In DNS Record Validator ***************")
    Rails.logger.debug("Exception :: #{e}")
    false
  end
  
  private
    def retrieve_dns_record(domain)
      dns = Dnsruby::Resolver.new
      dns.query(domain, Types.CNAME).answer
    end
    
    def validate(dkim_record)
      response = retrieve_dns_record(dkim_record.host_name)
      response.any? do |rrset|
        dkim_record.fd_cname.chomp('.') == rrset.cname.to_s.chomp('.')
      end
    end
end
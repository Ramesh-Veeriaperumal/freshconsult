class Dkim::ValidateDkimRecord
  include Dkim::Methods

  attr_accessor :domain_category, :current_account

  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def validate
    return update_verified_time unless Dkim::DnsRecordValidator.new(domain_category).check_records
    set_first_verification_time
    statuses = sg_domain_ids.collect do |id|
      response = make_api(SG_URLS[:validate_domain][:request], SG_URLS[:validate_domain][:url]%{:id => id})
      if response.first == API_SUCCESS_CODE
        update_dkim_records(response.last)
      end
      response.last['valid']
    end
    set_last_verified

    if statuses[0] and statuses[1]
      domain_category.status = OutgoingEmailDomainCategory::STATUS['active']
      domain_category.category = fetch_smtp_category
      domain_category.save!
      update_email_configs
    end
    domain_category
  end

  private
    def set_first_verification_time
      return if domain_category.first_verified_at
      domain_category.first_verified_at = Time.now
      domain_category.last_verified_at = Time.now
    end

    def set_last_verified
      domain_category.last_verified_at = Time.now      
    end
    
    def update_dkim_records(response)
      domain_category.dkim_records.where(:sg_id => response['id']).each do |dkim_record|
        dkim_record.status = response['validation_results']["#{dkim_record.sg_type}"]['valid']
        dkim_record.save if dkim_record.changes.present?
      end
    end
    
    def update_verified_time
      set_first_verification_time
      set_last_verified
      domain_category.save and domain_category
    end
    
    def update_email_configs
      domain_category.email_configs.update_all(:category => domain_category.category)
    end
end
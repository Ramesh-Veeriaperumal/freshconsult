class Dkim::ConfigureDkimRecord

  include Dkim::Methods

  attr_accessor :domain_category, :dkim_result, :current_account


  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def build_records
    raise Dkim::DomainAlreadyConfiguredError if sendgrid_verified_domain?(@domain_category.email_domain)
    Rails.logger.debug("fetch_smtp_category :: #{fetch_smtp_category} for Domain :: #{domain_category.email_domain}")
    domain_category.category = fetch_smtp_category # to build proper dns records
    add_whitelabel_to_domain
    add_dns_records_to_aws
    update_domain_category
    domain_category
  end

  def configure_domain_with_email_service
    response = Dkim::EmailServiceHttp.new(current_account.id, domain_category.email_domain).configure_domain
    if es_response_success?(response[:status])
      dkim_records = construct_dkim_hash([JSON.parse(response[:text])])
      update_domain_category
      dkim_records
    end
  end 

  private
    def add_whitelabel_to_domain
      response = request_configure
      save_sg_response(response[:record_1], response[:record_2])
      filter_dkim_records
    end

    def request_configure
      #lock in order to avoid multiple configuration calls to sendgrid/1 sec
      lock_dkim_configuration_in_progress
      Rails.logger.info("Request Sendgrid to Configure DKIM at #{Time.now.utc} for domain ::: #{domain_category.email_domain}")
      response_1 = make_api(SG_URLS[:create_domain][:request], SG_URLS[:create_domain][:url], build_dkim_record(domain_category.email_domain), SENDGRID_CREDENTIALS[:dkim_key][:user1])
      response_2 = make_api(SG_URLS[:create_domain][:request], SG_URLS[:create_domain][:url], build_dkim_record_1(domain_category.email_domain), SENDGRID_CREDENTIALS[:dkim_key][:user2])
      return {:record_1 => response_1, :record_2 => response_2}
    end

    def save_sg_response(response_1, response_2)
      Rails.logger.debug("save_sg_response ....... #{response_1.inspect} #{response_2.inspect}")
      response_codes = [response_1[0], response_2[0]]
      if response_codes.uniq.count == 1 && response_codes.first == SENDGRID_RESPONSE_CODE[:created]
        record_1 = response_1[1]
        record_2 = response_2[1]
      else
        domain_category.dkim_records.destroy_all if domain_category.dkim_records.present?
        subusers = SUB_USERS.keys
        response = make_api(SG_URLS[:get_domain][:request], SG_URLS[:get_domain][:url]%{:domain => domain_category.email_domain})
        Rails.logger.info("Fetched DKIM records on error ::: #{response.inspect}")
        domain_records = JSON.parse(response[1]) if response[0] == SENDGRID_RESPONSE_CODE[:success]
        record_1 = domain_records.select { |record| record['username'] == subusers[0] }[0]
        record_2 = domain_records.select { |record| record['username'] == subusers[1] }[0]
      end
      if record_1.present? && record_2.present?
        create_dkim_records(record_1, RECORD_TYPES[:res_1], domain_category.category)
        create_dkim_records(record_2, RECORD_TYPES[:res_2])
      else
        raise "DKIM config failed!"
      end
    end

    def add_dns_records_to_aws
      R53_ACTIONS.each do |content|
        Rails.logger.debug "content[0] :: #{content[0]}, content[1] :: #{content[1]}, content[2] :: #{ eval(content[2])}, content[3] :: #{ eval(content[3])}, content[4] :: #{content[4]}"
        if new_record?(content[2], content[1])
          handle_dns_action(content[0], content[1], eval(content[2]), eval(content[3]))
        elsif content[5] # account specific records
          handle_dns_action("UPSERT", content[1], eval(content[2]), eval(content[3]))
        end
        if content[4] # if customer record
          dkim_record = domain_category.dkim_records.where(:sg_type => content[6], :customer_record => true).first
          Rails.logger.debug "dkim_record ::: #{dkim_record.inspect}"
          next unless dkim_record
          dkim_record.fd_cname = eval(content[2])
          dkim_record.save!
        end
      end
    end

    def update_domain_category
      domain_category.category = nil
      domain_category.status = OutgoingEmailDomainCategory::STATUS['unverified']
      domain_category.save!
    end
end

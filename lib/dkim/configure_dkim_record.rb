class Dkim::ConfigureDkimRecord

  include Dkim::Methods

  attr_accessor :domain_category, :dkim_result, :current_account


  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def build_records
    Rails.logger.debug("fetch_smtp_category :: #{fetch_smtp_category} for Domain :: #{domain_category.email_domain}")
    domain_category.category = fetch_smtp_category # to build proper dns records
    add_whitelabel_to_domain
    add_dns_records_to_aws
    update_domain_category
    domain_category
  end

  private
    def add_whitelabel_to_domain
      response_1 = make_api(SG_URLS[:create_domain][:request], SG_URLS[:create_domain][:url], build_dkim_record(domain_category.email_domain))
      response_2 = make_api(SG_URLS[:create_domain][:request], SG_URLS[:create_domain][:url], build_dkim_record_1(domain_category.email_domain))
      save_sg_response(response_1, response_2)
      filter_dkim_records
    end

    def save_sg_response(response_1, response_2)
      Rails.logger.debug("save_sg_response ....... #{response_1.inspect} #{response_2.inspect}")
      if ([response_1[0], response_2[0]] - VALID_RESPONSE_CODE).empty?
        create_dkim_records(response_1[1], RECORD_TYPES[:res_1], domain_category.category)
        create_dkim_records(response_2[1], RECORD_TYPES[:res_2])
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
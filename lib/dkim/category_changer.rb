class Dkim::CategoryChanger
  include Dkim::Methods

  attr_accessor :domain_category, :current_account, :update_needed, :activity

  REQ_FIELDS_FOR_ACTIVITY = ["email_domain", "category", "status"]

  def initialize(domain_category, index = 1)
    @domain_category = domain_category
    @current_account = Account.current
    @update_needed = index.zero?
    @activity = domain_category.dkim_category_change_activities.new
  end

  def change_records
    save_current_domain_details
    make_default_category
    return false unless delete_custom_mail_server_records
    delete_from_db
    set_temporary_category
    create_in_sg
    update_aws_records
    activity.id
  end
  
  def switch_email_domains(activity_id)
    Dkim::ValidateDkimRecord.new(domain_category).validate
    if domain_category.status == OutgoingEmailDomainCategory::STATUS['active']
      switch_to_active_category
      switch_email_configs
      record_activity(activity_id)
    end
  end

  private
    def delete_custom_mail_server_records
      result = make_api(SG_URLS[:delete_domain][:request], SG_URLS[:delete_domain][:url]+custom_record_id.to_s)[0]
      result == DELETE_RESPONSE_CODE      
    end

    def custom_record_id
      domain_category.dkim_records.find_by_sg_type('dkim').sg_id
    end

    def delete_from_db
      domain_category.dkim_records.custom_records.destroy_all
    end

    def create_in_sg
      response = make_api(SG_URLS[:create_domain][:request], SG_URLS[:create_domain][:url], build_dkim_record(domain_category.email_domain, domain_category.category))
      return false unless VALID_RESPONSE_CODE.include?(response[0])
      create_dkim_records(response[1], RECORD_TYPES[:res_1])
    end

    def make_default_category
      domain_category.update_attribute(:category, OutgoingEmailDomainCategory::SMTP_CATEGORIES['default'])
      domain_category.email_configs.update_all(:category => domain_category.category)      
    end

    def update_aws_records
      Rails.logger.debug("$$$ update_aws_records $$$")
      filter_dkim_records
      R53_ACTIONS.each do |content|
        Rails.logger.debug("update_needed :: #{update_needed}, content[5] :: #{content[5]}, content[7] :: #{content[7]}")
        if update_needed and content[5] and content[7]
          Rails.logger.debug("content[1] :: #{content[1]}, eval(content[2]) :: #{eval(content[2])}, eval(content[3]) :: #{eval(content[3])}")
          handle_dns_action('UPSERT', content[1], eval(content[2]), eval(content[3]))
        end
        if content[4]
          dkim_record = domain_category.dkim_records.where(:sg_type => content[6]).first
          next unless dkim_record
          dkim_record.fd_cname = eval(content[2])
          dkim_record.save
        end
      end
    end
    
    def set_temporary_category # to update/set proper aws records based on this we will map CNAMES.
      domain_category.category = OutgoingEmailDomainCategory::SMTP_CATEGORIES[fetch_category]
    end

    def switch_to_active_category
      domain_category.category = OutgoingEmailDomainCategory::SMTP_CATEGORIES[fetch_category]
      domain_category.save!
    end

    def switch_email_configs
      domain_category.email_configs.update_all(:category => domain_category.category)      
    end

    def fetch_category
      (current_account.premium? ? 'premium' : current_account.subscription.state)
    end

    def record_activity(activity_id)
      activity = domain_category.dkim_category_change_activities.find_by_id(activity_id)
      activity.details[:current_details] = fetch_details
      activity.changed_on = Time.now
      activity.save
    end

    def save_current_domain_details
      activity.details = {:old_details => fetch_details}
      activity.changed_on = Time.now
      activity.save
    end

    def fetch_details
      domain_category.attributes.slice(*REQ_FIELDS_FOR_ACTIVITY).dup
    end  
end
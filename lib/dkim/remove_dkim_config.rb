class Dkim::RemoveDkimConfig
  include Dkim::Methods

  attr_accessor :domain_category, :current_account

  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def remove_records
    Rails.logger.debug("Remove dkim for #{domain_category.inspect}")
    domain_category.category = set_sendgrid_category_id if domain_category.category.blank?
    if delete_mail_server_records and delete_aws_records and update_email_configs and delete_dkim_records
      domain_category.category = nil
      domain_category.status = OutgoingEmailDomainCategory::STATUS['disabled']
      domain_category.save!
    end
  end

  private

    def delete_mail_server_records
      result = sg_domain_ids.collect do |domain_id|
        make_api(SG_URLS[:delete_domain][:request], SG_URLS[:delete_domain][:url]+domain_id.to_s)[0]
      end
      (result.uniq.count == 1 and result.first == SENDGRID_RESPONSE_CODE[:deleted]) || SENDGRID_RESPONSE_CODE[:not_found].in?(result)
    end

    def delete_aws_records
      return true unless last_email_domain?
      Rails.logger.debug("Last email domain result :::: #{last_email_domain?}")
      filter_dkim_records
      R53_ACTIONS.each do |content|
        if content[5] and !new_record?(content[2], content[1]) && domain_category.category.present?
          handle_dns_action('DELETE', content[1], eval(content[2]), eval(content[3]))
        end
      end
    end

    def update_email_configs
      domain_category.email_configs.update_all(:category => nil)
    end

    def last_email_domain?
      Rails.logger.debug("DKIM Configured count ::: #{scoper.dkim_configured_domains.count}")
      scoper.dkim_configured_domains.count.zero?
    end
    
    def delete_dkim_records
      domain_category.dkim_records.destroy_all
    end
    
    def set_sendgrid_category_id
      id = domain_category.dkim_records.custom_records.pluck(:sg_category_id).first
      Rails.logger.info("Sendgrid Custom Category id :: #{id} for domain #{domain_category.email_domain}")
      unless OutgoingEmailDomainCategory::SMTP_CATEGORIES.key(id)
        id = domain_category.dkim_records.default_records.pluck(:sg_category_id).first
        Rails.logger.info("Sendgrid default Category id :: #{id} for domain #{domain_category.email_domain}")
        id = nil unless OutgoingEmailDomainCategory::SMTP_CATEGORIES.key(id)
      end
    end
end
class Dkim::RemoveDkim
  include Dkim::Methods

  attr_accessor :domain_category, :current_account

  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def remove
    delete_email_service_records
    delete_aws_records
    update_email_configs
    delete_dkim_records
    update_domain_category
    Rails.logger.debug "Succesfully deleted email service, aws, dkim_rec and updated email_configs, domain_category"
  rescue StandardError => e
    Rails.logger.info "Exception in dkim email service removal process : #{e}"
  end

  private

  def delete_email_service_records
    response = Dkim::EmailServiceHttp.new(current_account.id, domain_category.email_domain).remove_domain
    if response[:status] != Dkim::Constants::EMAIL_SERVICE_RESPONSE_CODE[:delete_success]
      Rails.logger.debug "Email service response #{response.inspect}" # only status and text will be there in response.
      raise 'Unsuccessful deletion in email service'
    end
  end

  def delete_aws_records
    # This is to support old sendgrid configured account which are migrated to email service.
    # dkim_records will not be present for accounts newly configured with email service.
    # Adding additional loggers here as we are facing frequent issues in this method.
    return true unless @domain_category.dkim_records.present? && last_email_domain?
    Rails.logger.debug "Last email domain result :::: #{last_email_domain?}"
    filter_dkim_records
    Rails.logger.debug "Domain category not present so skipping DNS action" unless domain_category.category.present?
    Rails.logger.debug "Started to delete aws records for acc #{@domain_category.account_id}"
    R53_ACTIONS.each do |content|
      if content[5] and !new_record?(content[2], content[1]) && domain_category.category.present?
        handle_dns_action('DELETE', content[1], eval(content[2]), eval(content[3]))
      end
    end
    Rails.logger.debug "Completed aws records deletion for acc #{@domain_category.account_id}"
  end

  def update_email_configs
    domain_category.email_configs.update_all(:category => nil)
  end

  def last_email_domain?
    Rails.logger.debug("DKIM Configured count ::: #{scoper.dkim_configured_domains.count}")
    scoper.dkim_configured_domains.count.zero?
  end

  def delete_dkim_records
    domain_category.dkim_records.destroy_all if @domain_category.dkim_records.present?
  end
  
  def update_domain_category
    @domain_category.category = nil
    @domain_category.status = OutgoingEmailDomainCategory::STATUS['disabled']
    @domain_category.save!
  end
end

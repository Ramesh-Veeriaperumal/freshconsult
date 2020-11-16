class Dkim::RemoveDkim
  include Dkim::Methods

  attr_accessor :domain_category, :current_account

  def initialize(domain_category)
    @domain_category = domain_category
    @current_account = Account.current
  end

  def remove
    email_service_records = fetch_records_for_domain
    delete_aws_records(email_service_records)
    delete_email_service_records(email_service_records)
    update_email_configs
    delete_dkim_records
    update_domain_category
    Rails.logger.debug "Succesfully deleted email service, aws, dkim_rec and updated email_configs, domain_category"
  rescue StandardError => e
    Rails.logger.info "Exception in dkim email service removal process for account #{current_account.id} : #{e}"
  end

  private

  def delete_email_service_records(records_from_email_service)
    if domain_records_present_in_email_service?(records_from_email_service)
      response = Dkim::EmailServiceHttp.new(current_account.id, domain_category.email_domain).remove_domain
      unless response[:status] == Dkim::Constants::EMAIL_SERVICE_RESPONSE_CODE[:delete_success]
        Rails.logger.debug "Email service response for #{current_account.id} - #{response.inspect}"
        raise 'Unsuccessful deletion in email service'
      end
    end
  end

  def delete_aws_records(email_service_records)
    # This is to support old sendgrid configured account which are migrated to email service.
    # dkim_records will not be present for accounts newly configured with email service.
    # Adding additional loggers here as we are facing frequent issues in this method.
    return true unless @domain_category.dkim_records.present? && last_email_domain?
    Rails.logger.debug "Last email domain result :::: #{last_email_domain?}"
    filter_dkim_records
    Rails.logger.debug "Domain category not present so skipping DNS action" unless domain_category.category.present?
    Rails.logger.debug "Started to delete aws records for acc #{@domain_category.account_id}"
    if domain_records_present_in_email_service?(email_service_records)
      delete_with_email_service_values(JSON.parse(email_service_records[:text])['records']['dkim'])
    else
      delete_with_fd_account_values
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

  def fetch_records_for_domain
    Dkim::EmailServiceHttp.new(current_account.id, domain_category.email_domain).fetch_domain
  end

  def domain_records_present_in_email_service?(domain_records)
    return true if domain_records[:status] == EMAIL_SERVICE_RESPONSE_CODE[:success]
  end

  def delete_with_email_service_values(email_dkim_records)
    return true if domain_category.category.blank?

    email_dkim_records.each do |record|
      host_selector = record['host'].split('.').first
      migrated_r53_records = fetch_migrated_r53_records(host_selector)
      next if migrated_r53_records.blank?

      next if new_record?(migrated_r53_records[1], migrated_r53_records[0])

      handle_dns_action('DELETE', migrated_r53_records[0], eval(migrated_r53_records[1]), record['value'])
    end
  end

  def delete_with_fd_account_values
    R53_ACTIONS.each do |content|
      next unless content[5] && !new_record?(content[2], content[1]) && domain_category.category.present?

      handle_dns_action('DELETE', content[1], eval(content[2]), eval(content[3]))
    end
  end

  def fetch_migrated_r53_records(host_selector)
    if FDM_SELECTORS.include?(host_selector)
      MIGRATED_ACCOUNTS_R53_ACTIONS[0]
    elsif FD_SELECTORS.include?(host_selector)
      MIGRATED_ACCOUNTS_R53_ACTIONS[1]
    elsif FD2_SELECTORS.include?(host_selector)
      MIGRATED_ACCOUNTS_R53_ACTIONS[2]
    end
  end
end

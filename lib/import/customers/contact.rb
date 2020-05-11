class Import::Customers::Contact < Import::Customers::Base

  def initialize(params={})
    super params
  end

  def default_validations
    item_param = @params_hash[:"#{@type}"]
    item_param[:time_zone].gsub!(/&amp;/, AND_SYMBOL) unless item_param[:time_zone].blank?

    cm_param = clean_client_manager_param item_param[:client_manager]
    company_param = clean_company_param item_param[:company_name]
    first_valid_company = company_param.compact[0]
    item_param[:email].strip! if item_param[:email]

    if import_multiple_companies?
      item_param[:client_manager] = cm_param.join(IMPORT_DELIMITER)
      item_param[:first_company_name] = first_valid_company
      item_param[:company_name] = company_param.join(IMPORT_DELIMITER)
    else
      item_param[:client_manager] = cm_param[0] if cm_param.present?
      item_param[:company_id] = current_account.companies.where(name: first_valid_company).first_or_create.id if first_valid_company.present?
      item_param.delete(:company_name)
    end
    load_item item_param
  end

  def create_imported_contact
    @params_hash[:user][:helpdesk_agent] = false #To make already deleted user active
    @item.signup!(@params_hash)
  rescue => e
    Rails.logger.debug "Error importing contact : #{Account.current.id} #{@params_hash.inspect}
                        #{e.message} #{e.backtrace}".squish
    false
  end

  private

  def load_item item_param
    email_param = item_param[:email]
    all_emails = []
    unless email_param.blank?
      all_emails = email_param.to_s.downcase.strip.split(IMPORT_DELIMITER)
      all_emails = all_emails.map! { |email| email.squish unless email.blank? }.uniq.compact
    end
    identifiers = {
      twitter_id: item_param[:twitter_id],
      unique_external_id: item_param[:unique_external_id]
    }
    identifiers[:email] = all_emails.first(User::MAX_USER_EMAILS) unless all_emails.blank?
    @item = current_account.all_users.find_by_an_unique_id(identifiers)

    @params_hash[:user][:all_emails] = all_emails if all_emails.length > 0
    @params_hash[:user][:deleted] = false unless @item.nil?
  end

  def clean_client_manager_param cm_param
    cm_values = cm_param.to_s.strip.downcase.split(IMPORT_DELIMITER)
    cm_values.map! { |cm_value| VALID_CLIENT_MANAGER_VALUES.include?(cm_value.squish) ?
                                cm_value.squish : "nil" }
  end

  def clean_company_param comp_param
    company_names = comp_param.to_s.strip.split(IMPORT_DELIMITER)
    company_names.map! { |c_name| c_name.squish.gsub(/&amp;/, AND_SYMBOL) unless c_name.blank? }
  end
end
class Import::Customers::Contact < Import::Customers::Base

  def initialize(params={})
    super params
  end

  def default_validations
    item_param = @params_hash[:"#{@type}"]
    item_param[:name] = "" if item_param[:name].nil? && item_param[:email].blank?

    cm_param = clean_client_manager_param item_param[:client_manager]
    company_param = clean_company_param item_param[:company_name]
    first_valid_company = company_param.compact[0]

    if is_user? && Account.current.features?(:multiple_user_companies)
      item_param[:client_manager] = cm_param.join(COMPANY_DELIMITER)
      item_param[:first_company_name] = first_valid_company
      item_param[:company_name] = company_param.join(COMPANY_DELIMITER)
    else
      item_param[:client_manager] = cm_param[0]
      item_param[:company_id] = current_account.companies.
                                find_or_create_by_name(first_valid_company).id unless
                                first_valid_company.blank?
    end
    load_item item_param
  end

  def create_imported_contact
    @params_hash[:user][:helpdesk_agent] = false #To make already deleted user active
    @item.signup!(@params_hash)
  end

  private

  def load_item item_param
    search_options = {:email => item_param[:email], :twitter_id => item_param[:twitter_id]}
    @item = current_account.all_users.find_by_an_unique_id(search_options)
    @params_hash[:user][:deleted] = false unless @item.nil?
  end

  def clean_client_manager_param cm_param
    cm_values = cm_param.to_s.strip.downcase.split(COMPANY_DELIMITER)
    cm_values.map! { |cm_value| VALID_CLIENT_MANAGER_VALUES.include?(cm_value.squish) ?
                                cm_value.squish : "nil" }
  end

  def clean_company_param comp_param
    company_names = comp_param.to_s.strip.split(COMPANY_DELIMITER)
    company_names.map! { |c_name| c_name.squish unless c_name.blank? }
  end
end
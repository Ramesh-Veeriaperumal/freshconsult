class ApiContactImportsController < ApiCustomerImportsController
  IMPORT_TYPE = 'contact'.freeze

  def self.wrap_params
    CONTACT_IMPORT_WRAP_PARAMS
  end

  def scoper
    current_account.contact_imports
  end

  def import_type
    IMPORT_TYPE
  end

  def stop_import_key
    format(STOP_CONTACT_IMPORT, account_id: current_account.id)
  end

  wrap_parameters(*wrap_params)
end

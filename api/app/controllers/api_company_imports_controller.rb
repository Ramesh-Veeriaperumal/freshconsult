class ApiCompanyImportsController < ApiCustomerImportsController
  IMPORT_TYPE = 'company'.freeze

  def self.wrap_params
    COMPANY_IMPORT_WRAP_PARAMS
  end

  def scoper
    current_account.company_imports
  end

  def import_type
    IMPORT_TYPE
  end

  def stop_import_key
    format(STOP_COMPANY_IMPORT, account_id: current_account.id)
  end

  wrap_parameters(*wrap_params)
end

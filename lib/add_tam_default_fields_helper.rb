module AddTamDefaultFieldsHelper

  def populate_tam_fields_data
    begin
      CompanyFieldsConstants::company_fields_data(account).each do |field_data|
      CompanyField.create_company_field(field_data, account)
      end
    rescue => e
      Rails.logger.info("Something went wrong while adding the TAM default fields")
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      account.company_form.clear_cache
    end
  end

  def account
    Account.current
  end
end
include CompanyFieldsConstants

account = Account.current

CompanyFieldsConstants::company_fields_data.each do |field_data|
  CompanyField.create_company_field(field_data, account)
end
account.company_form.clear_cache

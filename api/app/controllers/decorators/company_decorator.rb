class CompanyDecorator
  class << self
    def csv_to_array(input_csv)
      input_csv.nil? ? [] : input_csv.split(',')
    end

    def remove_prepended_text_from_company_fields(custom_fields, custom_fields_api_name_mapping=nil)
      custom_fields_api_name_mapping ||= Account.current.company_form.custom_company_fields.collect{ |x| [x.name.to_sym, x.api_name.to_sym] }.to_h
      CustomFieldDecorator.remove_prepended_text_from_custom_fields(custom_fields, custom_fields_api_name_mapping)
    end
  end
end

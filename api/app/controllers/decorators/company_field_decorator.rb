class CompanyFieldDecorator
  class << self
    def companies_custom_dropdown_choices(company_field)
      company_field.choices.map { |x| x[:value] }
    end
  end
end

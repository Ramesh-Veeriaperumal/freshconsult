class ApiCompanyFieldsDecorator < SimpleDelegator

  def companies_custom_dropdown_choices
    choices.map { |x| x[:value] }
  end
end
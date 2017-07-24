module CompanyFieldsTestHelper

  def create_custom_company_field options
    CompanyField.create_field options
  end


    def company_params options = {}
      {
       :field_options => options[:field_options] || nil,
       :type=> options[:type], 
       :field_type=> options[:field_type], 
       :label=> options[:label], 
       :required_for_agent=> options[:required_for_agent] || false, 
       :id=>nil, :custom_field_choices_attributes => options[:custom_field_choices_attributes] || [], :position=>rand(15..1000)
      }
    end

end
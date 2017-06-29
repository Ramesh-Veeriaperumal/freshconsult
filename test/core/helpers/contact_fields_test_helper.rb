module ContactFieldsTestHelper

	def create_custom_contact_field options
		ContactField.create_field options
	end

  def cf_params options = {}
    {
     :field_options => options[:field_options] || nil,
     :type=> options[:type], 
     :field_type=> options[:field_type], 
     :label=> options[:label], 
     :label_in_portal=> options[:label_in_portal] || options[:label], 
     :required_for_agent=> options[:required_for_agent] || false, 
     :visible_in_portal=> options[:visible_in_portal] || true, 
     :editable_in_portal=> options[:editable_in_portal] || true, 
     :required_in_portal=> options[:required_in_portal] || false, 
     :editable_in_signup=> options[:editable_in_signup] || false,
     :id=>nil, :custom_field_choices_attributes => options[:custom_field_choices_attributes] || [], :position=>rand(15..1000)
   }
  end

end
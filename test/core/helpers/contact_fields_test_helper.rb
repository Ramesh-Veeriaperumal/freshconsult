module ContactFieldsTestHelper

	def create_custom_contact_field options
		ContactField.create_field options
	end

	def custom_field_params
		[
			{ :type=>"paragraph", :field_type=>"custom_paragraph", :label=>"Testimony", :required_in_portal => "true", :editable_in_signup=> "true"},
			{ :type=>"text", :field_type=>"custom_text", :label=>"Linetext", :editable_in_signup=> "true"},
			{ :type=>"number", :field_type=>"custom_number", :label=>"Agt Count", :visible_in_portal=> "false"},
			{ :type=>"phone_number", :field_type=>"custom_phone_number", :label=>"Fax"},
			{ :type=>"url", :field_type=>"custom_url", :label=>"File URL", :editable_in_portal=> "false"},
			{ :type=>"date", :field_type=>"custom_date", :label=>"Date", :label_in_portal => "Calendar"},
			{ :type=>"checkbox", :field_type=>"custom_checkbox", :label=>"Show all ticket", :required_in_portal => "true"},
			{ :type=>"text", :field_type=>"custom_text", :label=>"Linetext with regex validation", 
				:field_options => {"regex"=>{"pattern"=>"(desk|service)", "modifier"=>"i"}}, 
				:editable_in_signup=> "true"},
       { :type => "dropdown", :field_type => "custom_dropdown", :label => "Category", 
        :custom_field_choices_attributes => [ {"value"=>"First", "position"=>1, "_destroy"=>0, "name"=>"First"}, 
                                              {"value"=>"Second", "position"=>2, "_destroy"=>0, "name"=>"Second"}, 
                                              {"value"=>"Third", "position"=>3, "_destroy"=>0, "name"=>"Third"},
                                              {"value"=>"Freshman", "position"=>4, "_destroy"=>0, "name"=>"Freshman"},
                                              {"value"=>"Tenth", "position"=>5, "_destroy"=>0, "name"=>"Tenth"}]}
      ]
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
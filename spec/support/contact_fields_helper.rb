module ContactFieldsHelper

	def create_contact_field options
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
        :choices => [["First", "0"], ["Second", "0"], ["Third", "0"], ["Tenth", "0"]]}
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
       :id=>nil, :choices=> options[:choices] || [], :position=>rand(15..1000)
     }
   end

   def date_time
    @dt ||= Time.now
  end

  def contact_params options = {}
    {
      "cf_linetext"=> options[:linetext] || "", 
      "cf_testimony" => options[:testimony] || "", 
      "cf_show_all_ticket" => options[:all_ticket] || "", 
      "cf_agt_count" => options[:agt_count] || "", 
      "cf_fax" => options[:fax] || "", 
      "cf_file_url" => options[:url] || "", 
      "cf_date" => options[:date] || "", 
      "cf_linetext_with_regex_validation" => options[:text_regex_vdt] || "",
      "cf_category" => options[:category] || ""
    }
  end

  def destroy_custom_fields
    Resque.inline = true
    contact_custom_field = @account.contact_form.fields.find(:all,:conditions=> ["column_name != ?", "default"])
    contact_custom_field.each { |field| field.delete_field }
    Resque.inline = false
  end
  
end
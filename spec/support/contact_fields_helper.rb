module ContactFieldsHelper

	def create_contact_field options
		ContactField.create_field options
	end

  def create_company_field options
    CompanyField.create_field options
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

  def contact_fields_values_with_faker options = {}
      {
      "cf_linetext"=> options[:linetext] || "#{Faker::Lorem.sentence(10)}", 
      "cf_testimony" => options[:testimony] || "#{Faker::Lorem.paragraph(3)}", 
      "cf_show_all_ticket" => options[:all_ticket] || true, 
      "cf_agt_count" => options[:agt_count] || "#{Faker::Number.number(6)}", 
      "cf_fax" => options[:fax] || "#{Faker::PhoneNumber.cell_phone}", 
      "cf_file_url" => options[:url] || "#{Faker::Internet.url}", 
      "cf_date" => options[:date] || "#{Date.today.to_s}", 
      "cf_linetext_with_regex_validation" => options[:text_regex_vdt] || "#{Faker::Lorem.sentence(10)}",
      "cf_category" => options[:category] || "#{["First", "Second", "Third"].sample}"
    }
  end


  def contact_default_attribute_values options ={}
    attributes = ActiveSupport::OrderedHash.new # Order of transfer of company and client_manager is important
    attributes[:company_id] = get_default_company.id
    attributes[:client_manager] = true
    attributes[:twitter_id] = options[:twitter_id] || "@#{Faker::Lorem.words(1)}"
    attributes[:phone] = options[:phone] || "#{Faker::PhoneNumber.phone_number}"
    attributes[:mobile] = options[:mobile] || "#{Faker::PhoneNumber.cell_phone}"
    attributes[:fb_profile_id] = options[:fb_profile_id] || "#{Faker::Lorem.words(1)}"
    attributes[:address] = options[:address] || "#{Faker::Address.street_address}"
    attributes[:external_id] = options[:external_id] || "#{Faker::Lorem.words(1)}"
    attributes[:job_title] = options[:job_title] || "#{Faker::Name.title}"
    attributes[:description] = options[:description] || "#{Faker::Lorem.paragraph(3)}"
    # TimeZone and Language won't be nil, hence won't be transferred to parent in testcases
    # attributes[:time_zone] = options[:time_zone] || "#{ ActiveSupport::TimeZone.all.map(&:name).sample}"
    # attributes[:language] = options[:language] || "#{I18n.available_locales.sample}"
    attributes
  end

  def destroy_custom_fields
    Resque.inline = true
    contact_custom_field = @account.contact_form.all_fields.find(:all,:conditions=> ["column_name != ?", "default"])
    contact_custom_field.each { |field| field.delete_field }
    Resque.inline = false
  end
  
end
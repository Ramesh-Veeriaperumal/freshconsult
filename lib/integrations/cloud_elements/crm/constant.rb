module Integrations::CloudElements
  module Crm::Constant

    CRM_TO_HELPDESK_FORMULA_ID = {
        :salesforce => '1312',
    }
    
    CUSTOM_FIELDS =  {"1001" => "text", "1002" => "phone_number", "1003" => "dropdown",
        "1004" => "number", "1005"  => "survey_radio", "1006" => "checkbox", "1007" => "date", 
        "1008" => "paragraph", "1009" => "url"}
    CONTACT_TYPES = { "1" => "text", "2" => "text", "3" => "email", "4" => "phone_number", "5" => "phone_number", 
        "6"=> "text", "7" => "text", "8" => "checkbox", "9" => "paragraph", "10" => "dropdown", "11" => "dropdown", 
        "12" => "text", "13" => "paragraph"}.merge!(CUSTOM_FIELDS)
    COMPANY_TYPES = {"1" => "text", "2" => "paragraph", "3" => "paragraph", "4"=> "text"}.merge!(CUSTOM_FIELDS)

  end
end
module Integrations::CloudElements
  module Crm::Constant

    APP_NAMES = {
        :sfdc => 'salesforce',
        :freshdesk => 'freshdesk',
        :dynamicscrm => 'dynamicscrm'
    }

    CRM_TO_HELPDESK_FORMULA_ID = {
        :salesforce => '1312',
        :dynamicscrm => '758'
    }

    HELPDESK_TO_CRM_FORMULA_ID = {
        :sfdc => '760',
        :dynamicscrm => '760'
    }
    
    API_KEY = '3MVG9ZL0ppGP5UrC7ycgr9IfYGKWrOe3Ke9gOzfPife6xgS.XNFCXko7jC.mpUNeF84vm9aGmEk2DOKAtSkfG'
    API_SECRET = '98436661440156758'
    CALLBACK_URL = 'http://localhost:3000/integrations/cloud_elements/crm/instances'
    
    CONTACT_TYPES = { "1" => "text", "2" => "text", "3" => "email", "4" => "phone_number", "5" => "phone_number", 
        "6"=> "text", "7" => "text", "8" => "checkbox", "9" => "paragraph", "10" => "dropdown", "11" => "dropdown", 
        "12" => "text", "13" => "paragraph", "1001" => "text", "1002" => "phone_number", "1003" => "dropdown",
        "1004" => "number", "1005"  => "survey_radio", "1006" => "checkbox", "1007" => "date", 
        "1008" => "paragraph", "1009" => "url"}

    FD_VALIDATOR = { 
        "text"=> ["string"],
        "email"=> [],
        "phone_number"=> ["string"],
        "checkbox"=> ["boolean"],
        "paragraph"=> ["string"],
        "dropdown"=> [], #????? string
        "number"=> ["number"],
        "survey_radio"=> [],
        "date"=> ["date"],
        "url"=> [] #????? string
    }

  end
end
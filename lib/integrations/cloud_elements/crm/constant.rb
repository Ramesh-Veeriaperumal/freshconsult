module Integrations::CloudElements
  module Crm::Constant

    APP_NAMES = {
        :sfdc => 'salesforce',
        :freshdesk => 'freshdesk',
        :dynamicscrm => 'dynamicscrm'
    }

    CRM_TO_HELPDESK_FORMULA_ID = {
        :salesforce => '1098',
        :dynamicscrm => '758'
    }

    HELPDESK_TO_CRM_FORMULA_ID = {
        :sfdc => '760',
        :dynamicscrm => '760'
    }
    
    API_KEY = '3MVG9ZL0ppGP5UrC7ycgr9IfYGKWrOe3Ke9gOzfPife6xgS.XNFCXko7jC.mpUNeF84vm9aGmEk2DOKAtSkfG'
    API_SECRET = '98436661440156758'
    CALLBACK_URL = 'https://localhost:3000/integrations/cloud_elements/crm/instances'
    
  end
end
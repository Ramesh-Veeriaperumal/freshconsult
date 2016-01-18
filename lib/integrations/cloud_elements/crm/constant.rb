module Integrations::CloudElements
  module Crm::Constant

    APP_NAMES = {
        :sfdc => 'salesforce',
        :freshdesk => 'freshdesk'
    }

    FORMULA_ID = {
        :sfdc => '547'
    }

    CRM_SYNC_TYPE = {
      :import => "sf_to_fd",
      :export => "fd_to_sf",
      :bidirectional => "both sf and fd"
    }
    
    API_KEY = '3MVG9ZL0ppGP5UrC7ycgr9IfYGKWrOe3Ke9gOzfPife6xgS.XNFCXko7jC.mpUNeF84vm9aGmEk2DOKAtSkfG'
    API_SECRET = '98436661440156758'
    CALLBACK_URL = 'https://jagdamba.ngrok.io/integrations/cloud_elements/crm/instances'
    
  end
end
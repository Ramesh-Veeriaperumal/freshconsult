module Integrations::Infusionsoft::Constant

   DOMAIN_URL = "https://api.infusionsoft.com"
   CONTACT_FIELDS = {         'City' => 'City',
                              'Company' => 'Company',
                              'Country' => 'Country',
                              'Email' => 'Email',                        
                              'First Name' => 'FirstName',
                              'Job Title' => 'JobTitle',
                              'Last Name' => 'LastName',
                              'Lead Source' => 'Leadsource',
                              'Owner' => 'OwnerID',
                              'Person Type' => 'ContactType',
                              'Phone 1' => 'Phone1',
                              'Phone1 Type' => 'Phone1Type',
                              'Postal Code' => 'PostalCode',
                              'State' => 'State',
                              'Street Address 1' => 'StreetAddress1',
                              'Street Address 2' => 'StreetAddress2',
                              'Website' => 'Website',
                              'Postal Code Extn' => 'ZipFour1',
                       }
   COMPANY_FIELDS = {         'City' => 'City',
                              'Company' => 'Company',
                              'Country' => 'Country',
                              'Email' => 'Email',                        
                              'Phone 1' => 'Phone1',
                              'Phone1 Type' => 'Phone1Type',
                              'Postal Code' => 'PostalCode',
                              'State' => 'State',
                              'Street Address 1' => 'StreetAddress1',
                              'Street Address 2' => 'StreetAddress2',
                              'Website' => 'Website',
                              'Postal Code Extn' => 'ZipFour1',
                        }

   REQUEST_BODY = "<?xml version='1.0' encoding='UTF-8'?><methodCall><methodName>DataService.query</methodName><params><param><value><string>privateKey</string></value></param><param><value><string>DataFormField</string></value></param><param><value><int>1000</int></value></param><param><value><int>0</int></value></param><param><value><struct><member><name>FormId</name><value><string>%{form_id}</string></value></member></struct></value></param><param><value><array><data><value><string>Name</string></value><value><string>Label</string></value><value><string>DataType</string></value></data></array></value></param></params></methodCall>"

   METADATA_REST_URL = "/crm/xmlrpc/v1?access_token="

   CONTACT_FORMID = -1
   ACCOUNT_FORMID = -6
   DATATYPE = "DataType"
   FIELD_NAME = "Name"
   FIELD_LABEL = "Label"
   EXCLUDED_DATA_TYPES = ['23','2']
   FETCH_INFUSIONSOFT_USERS = "fetch_infusionsoft_users:%{account_id}:%{inst_app_id}"
   EXPIRY_TIME = 1800
  
end
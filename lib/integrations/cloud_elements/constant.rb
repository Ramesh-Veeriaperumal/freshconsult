module Integrations::CloudElements::Constant

  BASE_DOMAIN = 'https://staging.cloud-elements.com/elements/api-v2'
  OAUTH_URL = 'elements/%{element}/oauth/url'
  API_KEY = '3MVG9ZL0ppGP5UrC7ycgr9IfYGKWrOe3Ke9gOzfPife6xgS.XNFCXko7jC.mpUNeF84vm9aGmEk2DOKAtSkfG'
  API_SECRET = '98436661440156758'
  CALLBACK_URL = 'https://jagdamba.ngrok.io/integrations/cloud_elements/instances'
  AUTH_HEADER = 'User m6uVXpHEaqhvPrq6VoU2DaezQ4mFaWb5L66qmNhsdP8=,Organization 403ba71daccf7a6faf248cd9083c7c61'
  CONTENT_TYPE = 'application/json'
  GET = 'get'
  POST = 'post'
  PUT = 'put'
  SYNC_TYPE = {
    :import => "sf_to_fd",
    :export => "fd_to_sf",
    :bidirectional => "both sf and fd"
  }
  CLOUD_ELEMENTS_AUTH = "cloud_elements_auth:%{account_id}:%{inst_app_id}"

  FD_INSTANCE_BODY =   {
      "element" => {"key" => "freshdesk"},
      "configuration" => {
        "username" => "%{api_key}",
        "password" => "X",
        "subdomain" => "sumitjagdambacom",
        "event.notification.enabled" => "true"
      },
      "tags" => [],
      "name" => "%{fd_instance}"
  }

  TRANSFORMATION_BODY = {
      "level" => "instance",
      "vendorName" => "%{object_name}",
      "fields" => [],
      "configuration" => [
        {
          "type" => "passThrough",
          "properties" => {
            "fromVendor" => false,
            "toVendor" => false
          }
        }
      ]
  }

  FORMULA_INSTANCE_BODY = {
      "formula" => {"active" => true},
      "name" => "%{formula_instance}",
      "active" => true,
      "configuration" => {
          "salesforce.source" => "%{element_instance_id}", 
          "freshdesk.target" => "%{fd_instance_id}"
      }
  }


CRM_ELEMENT_INSTANCE_BODY = {

  'sfdc' =>  {

    'objects' => {'contact' => 'Contact', 'account' => 'Account','lead' => 'Lead'},

    'parameters' => ['code'],

    'json_body'  => {
              'element' => {"key" => "sfdc"},
              'providerData' => {"code" => "%{code}"},
              'configuration' => {
                 'oauth.callback.url' => 'https://jagdamba.ngrok.io/integrations/cloud_elements/instances',
                 'oauth.api.key' => '3MVG9ZL0ppGP5UrC7ycgr9IfYGKWrOe3Ke9gOzfPife6xgS.XNFCXko7jC.mpUNeF84vm9aGmEk2DOKAtSkfG',
                 'oauth.api.secret' => '98436661440156758',
                 'event.vendor.type' => "webhook",
                 'event.notification.enabled' => "true",
                 'event.objects' => "Contact,Account"
              },
              'tags' => [],
              'name' => "%{element_name}"
    }
  },

  'dynamicscrm' => {

      'objects' => {'contact' => 'contact', 'account' => 'account','lead' => 'lead'},

      'parameters' => ['username','password','dynamicscrm_url'],

      'json_body'   => {
            'element' => {'key' => "dynamicscrm"},
            'configuration' => {
                "user.username" => "%{username}",
                "user.password" => "%{password}",
                "dynamics.tenant" => "%{dynamicscrm_url}",
                "document.tagging" => false,
                "event.notification.enabled" => "true",
                "event.vendor.type" => "polling"
              },
              'name' => "%{element_name}"
          }
    }       

}
end
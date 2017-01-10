module Dkim::Constants
  DNS_CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'pod_dns_config.yml'))
  SENDGRID_CONFIG = (YAML::load_file(File.join(Rails.root, 'config', 'sendgrid_webhook_api.yml')))[Rails.env]

  VALID_RESPONSE_CODE = [201, 400]

  DELETE_RESPONSE_CODE = 204

  API_SUCCESS_CODE = 200
  
  TRUSTED_PERIOD = 30
  
  FILTERED_DKIM_RECORDS = {}

  SUB_DOMAIN = 'fddkim'
  REQUEST_TYPES = {
    :get => 'get',
    :post => 'post',
    :delete => 'delete'
  }
  
  RECORD_TYPES = {
    :res_1 => ["mail_server", "subdomain_spf", "dkim"],
    :res_2 => ["mail_cname", "dkim1", "dkim2"]
  }

  SG_URLS = {
    :create_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains', :request => 'post'},
    :delete_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains/', :request => 'delete'},
    :validate_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains/%{id}/validate', :request => 'post'}
  }
  
  SENDGRID_CREDENTIALS = {"Authorization" => "Bearer  #{SENDGRID_CONFIG['sendgrid']['dkim_key']}",
                           "Content-Type" => 'application/json'}


  DOMAINKEY_RECORD = "%{client_sub_domain}.domainkey.#{AppConfig['base_domain'][Rails.env]}."

  DKIM_RECORDS = ['mail_server', 'dkim', 'dkim1', 'dkim2']

  REQ_FIELDS = ['id', 'user_id', 'username', 'dns']


  # 0 - Action 
  # 1 - Record type
  # 2 - building host value
  # 3 - building data
  # 4 - Is customer record?
  # 5 - need to delete while deletion or simply say account specific records
  # 6 - sg type to find and update records
  # 7 - category change required? or simply say custom records

  R53_ACTIONS = [
    ['CREATE',   'TXT',     "build_domain_key(OutgoingEmailDomainCategory::SMTP_CATEGORIES.key(domain_category.category)+'dkim')",        "FILTERED_DKIM_RECORDS['dkim'].to_json",                                                                     false, false,  true,           true],
    ['CREATE',   'CNAME',   "build_domain_key('acc'+Account.current.id.to_s)",                                                            "build_domain_key(OutgoingEmailDomainCategory::SMTP_CATEGORIES.key(domain_category.category)+'dkim')",       true,  true,   'dkim',         true],
    ['CREATE',   'TXT',     "build_domain_key('spfmx')",                                                                                  "FILTERED_DKIM_RECORDS['subdomain_spf'].to_json",                                                            false, false,  true,           true],
    ['CREATE',   'MX',      "build_domain_key('spfmx')",                                                                                  "'10 ' + FILTERED_DKIM_RECORDS['mail_server']",                                                              true,  false,  'mail_server',  true],

    ['CREATE',   'CNAME',   "build_domain_key('s1freshdeskdkim')",                                                                        "FILTERED_DKIM_RECORDS['dkim1']",                                                                            false, false,  false,          false],
    ['CREATE',   'CNAME',   "build_domain_key('s1acc'+Account.current.id.to_s)",                                                          "build_domain_key('s1freshdeskdkim')",                                                                       true,  true,   'dkim1',        false],

    ['CREATE',   'CNAME',   "build_domain_key('s2freshdeskdkim')",                                                                        "FILTERED_DKIM_RECORDS['dkim2']",                                                                            false, false,  false,          false],
    ['CREATE',   'CNAME',   "build_domain_key('s2acc'+Account.current.id.to_s)",                                                          "build_domain_key('s2freshdeskdkim')",                                                                       true,  true,   'dkim2',        false],  
  ]
end
module Dkim::Constants
  DNS_CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'pod_dns_config.yml'))
  SENDGRID_CONFIG = (YAML::load_file(File.join(Rails.root, 'config', 'sendgrid_webhook_api.yml')))[Rails.env]

  SENDGRID_RESPONSE_CODE = {
    :success => 200,
    :created => 201,
    :deleted => 204,
    :too_many_requests => 429,
    :failed => 400,
    :not_found => 404,
  }
  
  TRUSTED_PERIOD = 30
  
  FILTERED_DKIM_RECORDS = {}

  SUB_DOMAIN = 'fddkim'
  REQUEST_TYPES = {
    :get => 'get',
    :post => 'post',
    :delete => 'delete'
  }
  CONFIGURE_EXPIRE_TIME = SENDGRID_CONFIG['sendgrid']['dkim']['configure']['expire']
  
  RECORD_TYPES = {
    :res_1 => ["mail_server", "subdomain_spf", "dkim"],
    :res_2 => ["mail_cname", "dkim1", "dkim2"]
  }

  SG_URLS = {
    :create_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains', :request => 'post'},
    :delete_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains/', :request => 'delete'},
    :validate_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains/%{id}/validate', :request => 'post'},
    :get_domain => {:url => 'https://api.sendgrid.com/v3/whitelabel/domains?domain=%{domain}', :request => 'get'}
  }
  
  SUB_USERS = SENDGRID_CONFIG['sendgrid']['dkim']['key']['sub_users']

  SUB_USER_API_KEYS = SUB_USERS.values

  SENDGRID_CREDENTIALS = {
      :dkim_key => {  :user1 => {"Authorization" => "Bearer  #{SUB_USER_API_KEYS[0]}",
                                                      "Content-Type" => 'application/json'},
                      :user2 => {"Authorization" => "Bearer  #{SUB_USER_API_KEYS[1]}",
                                                      "Content-Type" => 'application/json'},
                      :parent => {"Authorization" => "Bearer  #{SENDGRID_CONFIG['sendgrid']['dkim']['key']['parent']}",
                                                      "Content-Type" => 'application/json'}    
      }
  }


  DOMAINKEY_RECORD = "%{client_sub_domain}.domainkey.#{AppConfig['base_domain'][Rails.env]}."

  DKIM_RECORDS = ['mail_server', 'dkim', 'dkim1', 'dkim2']

  REQ_FIELDS = ['id', 'user_id', 'username', 'dns']

  DKIM_SELECTOR = { mrecord: 'fdm', srecord: 'fd' }.freeze

  DKIM_CONFIGURE_TIMEOUT = SENDGRID_CONFIG['sendgrid']['dkim']['configure']['timeout']
  DKIM_CONFIGURE_RETRIES = SENDGRID_CONFIG['sendgrid']['dkim']['configure']['retries']

  # 0 - Action 
  # 1 - Record type
  # 2 - building host value
  # 3 - building data
  # 4 - Is customer record?
  # 5 - need to delete while deletion or simply say account specific records
  # 6 - sg type to find and update records
  # 7 - category change required? or simply say custom records

  R53_ACTIONS = [
    ['CREATE',   'TXT',     "build_domain_key('fdmdkim')",                       "FILTERED_DKIM_RECORDS['dkim'].to_json",          false, false,  true,           true],
    ['CREATE',   'CNAME',   "build_domain_key('acc'+Account.current.id.to_s)",    "build_domain_key('fdmdkim')",                   true,  true,   'dkim',         true],
    ['CREATE',   'TXT',     "build_domain_key('spfmx')",                          "FILTERED_DKIM_RECORDS['subdomain_spf'].to_json", false, false,  true,           true],
    ['CREATE',   'MX',      "build_domain_key('spfmx')",                          "'10 ' + FILTERED_DKIM_RECORDS['mail_server']",   true,  false,  'mail_server',  true],
    ['CREATE',   'CNAME',   "build_domain_key('fdfreshdeskdkim')",                "FILTERED_DKIM_RECORDS['dkim1']",                 false, false,  false,         false],
    ['CREATE',   'CNAME',   "build_domain_key('fdacc'+Account.current.id.to_s)",  "build_domain_key('fdfreshdeskdkim')",            true,  true,  'dkim1',        false],
    ['CREATE',   'CNAME',   "build_domain_key('fd2freshdeskdkim')",               "FILTERED_DKIM_RECORDS['dkim2']",                 false, false,  false,         false],
    ['CREATE',   'CNAME',   "build_domain_key('fd2acc'+Account.current.id.to_s)", "build_domain_key('fd2freshdeskdkim')",           true,  true,  'dkim2',        false] 
  ]

  MIGRATED_ACCOUNTS_R53_ACTIONS = {
    0 => ['CNAME', "build_domain_key('acc'+Account.current.id.to_s)"],
    1 => ['CNAME', "build_domain_key('fdacc'+Account.current.id.to_s)"],
    2 => ['CNAME', "build_domain_key('fd2acc'+Account.current.id.to_s)"]
  }.freeze

  FDM_SELECTORS = ['fdm', 'm1'].freeze
  FD_SELECTORS = ['fd', 's1'].freeze
  FD2_SELECTORS = ['fd2', 's2'].freeze

  FD_EMAIL_SERVICE = YAML.load_file(File.join(Rails.root, 'config', 'fd_email_service.yml'))[Rails.env]
  EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE['key']
  EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE['dkim_host']
  EMAIL_SERVICE_GET_DOMAINS = FD_EMAIL_SERVICE['get_domains']
  EMAIL_SERVICE_CONFIGURE_DOMAIN = FD_EMAIL_SERVICE['configure_domain']
  EMAIL_SERVICE_VERIFY_DOMAIN = FD_EMAIL_SERVICE['verify_domain']
  EMAIL_SERVICE_REMOVE_DOMAIN = FD_EMAIL_SERVICE['remove_domain']
  EMAIL_SERVICE_GET_DOMAIN = FD_EMAIL_SERVICE['fetch_domain']
  EMAIL_SERVICE_RESPONSE_CODE = {
    success: 200,
    delete_success: 204
  }.freeze
  EMAIL_SERVICE_ACTION = {
    get_domains: :get_domains,
    configure_domain: :configure_domain,
    verify_domain: :verify_domain,
    remove_domain: :remove_domain,
    fetch_domain: :fetch_domain
  }.freeze
end

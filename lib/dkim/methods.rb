module Dkim::Methods
  include Dkim::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Dkim::UtilityMethods

  def handle_dns_action(action, record_type, record_name, record_value)
    Rails.logger.debug("Handle Dns Action ::: action - #{action}, record_type - #{record_type},
      record_name - #{record_name}, record_value - #{record_value}")
    route53 = AWS::Route53::Client.new(:access_key_id => PodConfig["access_key_id"],
  		:secret_access_key => PodConfig["secret_access_key"],
  		:region => PodConfig["region"])
    route53.change_resource_record_sets({
        :hosted_zone_id => DNS_CONFIG["hosted_zone"],
        :change_batch => {:changes => [build_record_attributes(action, record_type, record_name, record_value)]}
    }) 
  end

  def new_record?(domainkey, record_type)
    domainkey = eval(domainkey)
    route53_client = AWS::Route53::Client.new(:region => PodConfig["region"])
    response = route53_client.list_resource_record_sets({
      hosted_zone_id: PodDnsUpdate::DNS_CONFIG["hosted_zone"],
      start_record_name: domainkey,
      start_record_type: record_type,
      max_items: 1
    })
    !(response.resource_record_sets && response.resource_record_sets.first[:name] == domainkey)
  end

  def build_record_attributes(action, record_type, record_name, record_value)
    { 
      :action => action,
      :resource_record_set => {
        :name => record_name,
        :type => record_type,
        :ttl => 600,
        :resource_records=>[{:value=>record_value}]
    }}
  end

  def make_api(req_type, url, data={}, key=SENDGRID_CREDENTIALS[:dkim_key][:parent])
    if req_type.to_s == REQUEST_TYPES[:get] or req_type.to_s == REQUEST_TYPES[:delete]
      response = RestClient.safe_send(req_type, url, key)
    elsif req_type.to_s == REQUEST_TYPES[:post]
      response = RestClient.safe_send(req_type, url, data, key)
    end
    response.headers[:content_length].to_i > 2 ? [response.code.to_i, JSON.parse(response)] : [response.code.to_i, response]
  rescue RestClient::RequestFailed, RestClient::ResourceNotFound => e
    [e.response.code.to_i, e.response]
  end
  
  def filter_dkim_records
    records = domain_category.dkim_records.filter_records
    result = records.each_with_object({}) do |dkim_record, result|
      result[dkim_record.sg_type] = dkim_record.host_value
    end
    Rails.logger.debug "records :: #{records.inspect}"
    FILTERED_DKIM_RECORDS.merge!(result)
    Rails.logger.debug "FILTERED_DKIM_RECORDS :: #{FILTERED_DKIM_RECORDS.inspect}"
  end
  
  def create_dkim_records(response, req_records, category = 5) # default category 5
    req_records.each do |rec|
      Rails.logger.debug "response :: #{response.inspect} rec -> #{rec}_records"
      data = Dkim::SendgridParser.new(response, category).safe_send("#{rec}_records")
      Rails.logger.debug "In create dkim_records..... #{data.inspect}"
      domain_category.dkim_records.new(data).save!
    end
  end

  def build_domain_key(subdomain)
    DOMAINKEY_RECORD % {:client_sub_domain => subdomain}
  end

  def sg_domain_ids
    domain_category.dkim_records.pluck(:sg_id).uniq
  end

  def scoper
    current_account.outgoing_email_domain_categories
  end

  def build_dkim_record(domain, sg_user = fetch_smtp_category)
    {
      "domain"=> domain,
      "subdomain"=> SUB_DOMAIN,
      "ips"=>  [],
      "custom_spf"=> true,
      "default"=> false,
      "automatic_security" => false,
      "custom_dkim_selector" => DKIM_SELECTOR[:mrecord]
    }.to_json 
  end

  def build_dkim_record_1(domain)
    {
      "domain"=> domain,
      "subdomain"=>  SUB_DOMAIN,
      "ips" =>  [],
      "custom_spf" => false,
      "default"=> false,
      "automatic_security" => true,
      "custom_dkim_selector" => DKIM_SELECTOR[:srecord]
    }.to_json
  end

  def fetch_sendgrid_username(category_id)
    Helpdesk::EMAIL["category-#{category_id}".to_sym][Rails.env.to_sym][:user_name]
  end
  
  def dkim_verify_key(domain_category)
    DKIM_VERIFICATION_KEY % { :account_id => Account.current.id, :email_domain_id => domain_category.id }
  end
  
  def fetch_smtp_category
    category = (previous_category or premium_category or other_category or 'default')
    OutgoingEmailDomainCategory::SMTP_CATEGORIES[category]
  end

  def premium_category
    (current_account.premium? ? 'premium' : nil)
  end

  def other_category
    Rails.logger.debug("other_category :: #{current_account.created_at < TRUSTED_PERIOD.days.ago}")
    (current_account.created_at < TRUSTED_PERIOD.days.ago ? current_account.subscription.state : Subscription::TRIAL)
  end

  def previous_category
    prev_cat = scoper.dkim_activated_domains.first.try(:category) # already activated domains
    return retrieve_category_name(prev_cat) if prev_cat.present?
    
    prev_email_domain = scoper.dkim_configured_domains.first  # configured domains list
    return nil if prev_email_domain.blank? # first dkim configure
    
    custom_dkim_records = prev_email_domain.dkim_records.custom_records #using custom_records category id
    return retrieve_category_name(custom_dkim_records.pluck(:sg_category_id).first) if custom_dkim_records
    
  end
  
  def retrieve_category_name(cat_id)
    Rails.logger.debug("previous_category :: #{cat_id}")
    OutgoingEmailDomainCategory::SMTP_CATEGORIES.key(cat_id)
  end

  def is_any_dkim_configuration_in_progress?
    last_configure_time = get_others_redis_key(DKIM_CONFIGURATION_IN_PROGRESS_KEY)
    return last_configure_time.blank? ? false : (Time.now.utc.to_i - last_configure_time.to_i) < CONFIGURE_EXPIRE_TIME
  end

  def lock_dkim_configuration_in_progress
    set_others_redis_key(DKIM_CONFIGURATION_IN_PROGRESS_KEY, Time.now.utc.to_i, CONFIGURE_EXPIRE_TIME.seconds)
  end

  def unlock_dkim_configuration_in_progress
    remove_others_redis_key(DKIM_CONFIGURATION_IN_PROGRESS_KEY)
  end

  def configure_with_retry_timeout
    Timeout.timeout(DKIM_CONFIGURE_TIMEOUT) do 
      with_retries(:limit => DKIM_CONFIGURE_RETRIES){ configure } 
    end
  end

  def configure
    unless is_any_dkim_configuration_in_progress?
      Dkim::ConfigureDkimRecord.new(@domain_category).build_records
    else
      raise "Another DKIM Configuration is in progress!"
    end
  end

end

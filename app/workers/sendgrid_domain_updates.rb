require 'resolv'

class SendgridDomainUpdates < BaseWorker

  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis

  require 'freemail'

  TIMEOUT = SendgridWebhookConfig::CONFIG[:timeout]

  sidekiq_options :queue => :sendgrid_domain_updates, :retry => 3, :backtrace => true, :failures => :exhausted

  def perform(args)
    return if Rails.env.development?
    begin 
      unless args['action'].blank?
        domain_in_sendgrid = sendgrid_domain_exists?(args['domain'])
        if (!domain_in_sendgrid && args['action'] == 'delete')
          Rails.logger.info "Domain #{args['domain']} does not exist in sendgrid to delete"
        elsif (domain_in_sendgrid && args['action'] == 'create')
          notify_and_update(args['domain'], args['vendor_id'])
        elsif (args['action'] == 'create' or args['action'] == 'delete')
          Rails.logger.info "Sendgrid #{args['action']} triggered for domain #{args['domain']}"
          self.send("#{args['action']}_record", args['domain'], args['vendor_id'])
        end
      end
    rescue => e
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => args['domain']}, e, {
        :subject => "Error in updating domain in sendgrid", 
        :recipients => "mail-alerts@freshdesk.com" 
        })
      raise e
    end
  end

  def sendgrid_domain_exists?(domain)
    response = send_request('get', SendgridWebhookConfig::SENDGRID_API['get_specific_domain_url'] + domain)
    return true if response.code == 200
  end

  def delete_record(domain, vendor_id)
    response = send_request('delete', SendgridWebhookConfig::SENDGRID_API["delete_url"] + domain)
    Rails.logger.info "Response code for sendgrid delete action code: #{response.code}, message: #{response.message}"
    return false unless response.code == 204
    Rails.logger.info "Deleted domain #{domain} from sendgrid"
    AccountWebhookKey.destroy_all(account_id: Account.current.id, vendor_id: vendor_id)
  end

  def create_record(domain, vendor_id)
    generated_key = generate_callback_key
    check_spam_account
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = {:hostname => domain, :url => post_url, :spam_check => false, :send_raw => false }
    response = send_request('post', SendgridWebhookConfig::SENDGRID_API["set_url"] , post_args)
    Rails.logger.info "Response for sendgrid create action code: #{response.code}, message: #{response.message}"
    return false unless response.code == 200
    verification = AccountWebhookKey.new(:account_id => Account.current.id, 
      :webhook_key => generated_key, :vendor_id => vendor_id, :status => 1)
    verification.save!
  end

  def check_spam_account
    account = Account.find_by_id(Account.current.id)
    if account.present?
      admin_email_domain = parse_email_with_domain(account.admin_email)[:domain]
      resolver = Resolv::DNS.new
      mxrecord = resolver.getresources(admin_email_domain,Resolv::DNS::Resource::IN::MX) if admin_email_domain.present?
      
      spam_email_exact_regex_value = get_others_redis_key(SPAM_EMAIL_EXACT_REGEX_KEY)
      spam_email_apprx_regex_value = get_others_redis_key(SPAM_EMAIL_APPRX_REGEX_KEY)
      spam_email_exact_match_regex = spam_email_exact_regex_value.present? ? Regexp.compile(spam_email_exact_regex_value, true) : SPAM_EMAIL_EXACT_REGEX
      spam_email_apprx_match_regex = spam_email_apprx_regex_value.present? ? Regexp.compile(spam_email_apprx_regex_value, true) : SPAM_EMAIL_APPRX_REGEX

      stop_sending = true
      if mxrecord.blank?
        spam_score = 5 
        reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: Invalid Admin contact address"
      elsif ismember?(BLACKLISTED_SPAM_DOMAINS,admin_email_domain)
        spam_score = 5
        reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: Blacklisted admin email domain"
      elsif Freemail.disposable?(account.admin_email)
        spam_score = 5
        reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: Disposable admin email address"
      elsif ((account.helpdesk_name =~ spam_email_exact_match_regex || account.full_domain =~ spam_email_exact_match_regex) && Freemail.free?(account.admin_email))
        spam_score = 5
        reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: Account name contains exact suspicious words"
      else
        signup_params = get_account_signup_params(Account.current.id)
        if (signup_params["account_details"].present? && signup_params["metrics"].present?)
          begin
            signup_params["api_response"] = Email::AntiSpam.scan(signup_params,Account.current.id) 
            signup_params["api_response"]["status"] = -1 if (signup_params["api_response"].present? && !signup_params["api_response"]["status"].present?)
            save_account_sign_up_params(Account.current.id, signup_params)
            Rails.logger.info "Response by Ehawk Email Verifier account - #{account.id} ::: email - #{signup_params["account_details"]["email"]} ::: ip - #{signup_params["account_details"]["source_ip"]} ::: status - #{signup_params["api_response"]["status"]} ::: reason - #{signup_params["api_response"]["reason"]} "
          rescue => e
            Rails.logger.error "Error while processing Ehawk Emai lVerifier \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          end
        end
        if signup_params["api_response"] && signup_params["api_response"]["status"] == 5
          spam_score = 5
          reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: #{signup_params["api_response"]["reason"]}"
        elsif((account.helpdesk_name =~ spam_email_apprx_match_regex || account.full_domain =~ spam_email_apprx_match_regex) && Freemail.free?(account.admin_email)) 
          spam_score = 4 
          stop_sending = false
          reason = "Reason: Account name looks suspicious for Account ID: #{account.id}"
        elsif signup_params["api_response"] && signup_params["api_response"]["status"] == 4
          spam_score = 4
          stop_sending = false
          reason = "Account credetials looks suspicious for Account ID: #{account.id} , Reason: #{signup_params["api_response"]["reason"]}"
        elsif signup_params["api_response"] && signup_params["api_response"]["status"]
          spam_score = signup_params["api_response"]["status"] 
        else 
          spam_score = 0
        end
      end

      unless account.conversion_metric.nil?
        account.conversion_metric.spam_score = spam_score
        account.conversion_metric.save
      end

      if (account.full_domain =~ /support/i && (spam_score >= 4  || Freemail.free_or_disposable?(account.admin_email)))
        sleep(5)
        Account.current.subscription.update_attributes(:state => "suspended")
        ShardMapping.find_by_account_id(Account.current.id).update_attributes(:status => 403)
        notify_blocked_spam_account_detection(account, "Reason: Domain url contains support and signup using free or spam email domains")
      elsif spam_score >= 4
        blacklist_spam_account(account, stop_sending, reason)
      end
    end
  end


  def notify_blocked_spam_account_detection(account, additional_info)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
            :subject => "Blocked suspicious spam account :#{account.id} ",
            :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com"],
            :additional_info => {:info => additional_info}
          })
  end

  def blacklist_spam_account(account, is_spam_email_account, additional_info )
    add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, account.id) if is_spam_email_account
    add_member_to_redis_set(BLACKLISTED_SPAM_ACCOUNTS, account.id)
    notify_spam_account_detection(account, additional_info)
  end

  def notify_spam_account_detection(account, additional_info)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
            :subject => "Detected suspicious spam account :#{account.id} ", 
            :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com"],
            :additional_info => {:info => additional_info}
          })
  end

  def notify_and_update(domain, vendor_id)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, nil, {
      :subject => "Error in creating mapping for a domain in sendgrid", 
      :recipients => "mail-alerts@freshdesk.com",
      :additional_info => {:info => "Domain already exists in sendgrid"}
      })

    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = { :url => post_url, :spam_check => false, :send_raw => false }
    response = send_request('patch', SendgridWebhookConfig::SENDGRID_API['update_url'] + domain, post_args)
    Rails.logger.info "Response message for sendgrid update action code: #{response.code}, message: #{response.message}"
    webhook_key = AccountWebhookKey.find_by_account_id_and_vendor_id(Account.current.id, vendor_id)
    webhook_key.update_attributes(:webhook_key => generated_key) if webhook_key.present?
  end

  def send_request(action, url, post_args={})
    Timeout::timeout(TIMEOUT) do
      response = HTTParty.send(action, url, :body => post_args.to_json, 
        :headers => { "Authorization" => "Bearer #{SendgridWebhookConfig::CONFIG['api_key']}" })
    end
  end

  def generate_callback_key
    SecureRandom.hex(15)
  end

  def get_account_signup_params account_id
    key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => account_id}
    json_response = get_others_redis_key(key)
    if json_response.present?
      parsed_response = JSON.parse(json_response)
    else
      parsed_response = {}
    end
    parsed_response
  end

  def save_account_sign_up_params account_id, args = {}
    key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => account_id}
    set_others_redis_key(key,args.to_json,1296000)
    increment_portal_cache_version
  end

  def increment_portal_cache_version
    return if get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false"
    Rails.logger.debug "::::::::::Sweeping from portal"
    key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
    increment_portal_redis_version key
  end

end

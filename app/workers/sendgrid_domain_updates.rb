require 'resolv'

class SendgridDomainUpdates < BaseWorker

  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis
  include EmailHelper

  require 'freemail'

  TIMEOUT = SendgridWebhookConfig::CONFIG[:timeout]

  sidekiq_options :queue => :sendgrid_domain_updates, :retry => 3, :failures => :exhausted

  def perform(args)
    sleep(5)
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
          self.safe_send("#{args['action']}_record", args['domain'], args['vendor_id'])
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
    Rails.logger.info "Response code for sendgrid delete action, Account id : #{Account.current.id},  code: #{response.code}, message: #{response.message}"
    return false unless response.code == 204
    Rails.logger.info "Deleted domain #{domain} from sendgrid"
    AccountWebhookKey.destroy_all(account_id: Account.current.id, vendor_id: vendor_id)
  end

  def create_record(domain, vendor_id)
    generated_key = generate_callback_key
    check_spam_account
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = {:hostname => domain, :url => post_url, :spam_check => false, :send_raw => true }
    response = send_request('post', SendgridWebhookConfig::SENDGRID_API["set_url"] , post_args)
    Rails.logger.info "Response for sendgrid create action, Account id : #{Account.current.id} , code: #{response.code}, message: #{response.message}, portal :#{domain}"
    return false unless response.code == 200
    verification = AccountWebhookKey.new(:account_id => Account.current.id, 
      :webhook_key => generated_key, :vendor_id => vendor_id, :status => 1)
    verification.save!
  end

  def check_spam_account
    account = Account.find_by_id(Account.current.id)
    if account.present?
      stop_sending = false
      signup_params = get_account_signup_params(Account.current.id)
      if (signup_params["account_details"].present?)
        begin
          signup_params["api_response"] = Email::AntiSpam.scan(signup_params, Account.current.id, account.helpdesk_name, account.full_domain)
          mask_new_response signup_params["api_response"]
          signup_params["api_response"]["status"] = -1 if (signup_params["api_response"].blank? || signup_params["api_response"]["status"].blank?)
          save_account_sign_up_params(Account.current.id, signup_params)
          Rails.logger.info "Response by EmailServ account validate account - #{account.id} ::: email - #{signup_params["account_details"]["email"]} ::: ip - #{signup_params["account_details"]["source_ip"]} ::: status - #{signup_params["api_response"]["status"]} ::: reason - #{signup_params["api_response"]["reason"].to_a.to_sentence} "
        rescue => e
          Rails.logger.error "Error while processing Ehawk Email Verifier \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        else
          Rails.logger.error "No signup params received for Account ID: #{account.id}"
        end
      else
          Rails.logger.info "Account - #{account.id} , account_details not found"
      end
        
      if signup_params["api_response"] && signup_params["api_response"]["status"] == 5
        spam_score = 5
        stop_sending = true
        reason = "Outgoing will be blocked for Account ID: #{account.id} , Reason: #{signup_params["api_response"]["reason"].to_a.to_sentence} IP: #{signup_params["account_details"]["source_ip"]}, Email: #{signup_params["account_details"]["email"]}, Spam Status: 5"
      elsif signup_params["api_response"] && signup_params["api_response"]["status"] == 4
        spam_score = 4
        reason = "Account credetials looks suspicious for Account ID: #{account.id} , Reason: #{signup_params["api_response"]["reason"].to_a.to_sentence} IP: #{signup_params["account_details"]["source_ip"]}, Email: #{signup_params["account_details"]["email"]}, Spam Status: 4"
      elsif signup_params["api_response"] && signup_params["api_response"]["status"]
        spam_score = signup_params["api_response"]["status"] 
      else 
        spam_score = -1
      end

      unless account.conversion_metric.nil?
        account.conversion_metric.spam_score = spam_score
        # When spam_score gets assigned to the default value(0) again, ActiveRecord doesn't generate model changes
        # Changes to spam_score are necessary for contact enrichment callback to trigger
        account.conversion_metric.spam_score_will_change! 
        account.conversion_metric.save
      end

      if (account.full_domain =~ /support/i)
        if spam_score >=4
         sleep(5)
         Account.current.subscription.update_attributes(:state => "suspended")
         ShardMapping.find_by_account_id(Account.current.id).update_attributes(:status => 403)
         notify_blocked_spam_account_detection(account, "Reason: Domain url contains support and spam score is > 3")
        elsif Freemail.free_or_disposable?(account.admin_email)
         blacklist_spam_account(account, stop_sending, "Reason: Domain url contains support and signup using free or spam email domains")
        end
      elsif spam_score >= 4
        blacklist_spam_account(account, stop_sending, reason)
      end
    end
  end

  def mask_new_response response
    if response 
      if response["RISK SCORE"]
        response["status"] = response["RISK SCORE"] 
        response.delete("RISK SCORE")
      end
      if response["REASON"]
        response["reason"] = response["REASON"] 
        response.delete("REASON")
      end
    end
  end

  def notify_blocked_spam_account_detection(account, additional_info)
    subject = "Blocked suspicious spam account :#{account.id} "
    notify_account_blocks(account, subject, additional_info)
    update_freshops_activity(account, "Account blocked due to high spam score & support keyword ", "block_account")
  end

  def blacklist_spam_account(account, is_spam_email_account, additional_info )
    add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, account.id) if is_spam_email_account
    account.enable_setting(:spam_blacklist_feature)
    notify_spam_account_detection(account, additional_info, is_spam_email_account)
  end

  def notify_spam_account_detection(account, additional_info, is_spam_email_account = false)
    subject = "Detected suspicious spam account :#{account.id} "
    if is_spam_email_account
      notify_account_blocks(account, subject, additional_info)
      update_freshops_activity(account, "Outgoing emails blocked due to high spam score", "block_outgoing_email")
    else
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
            :subject => subject, 
            :recipients => ["mail-alerts@freshdesk.com", "helpdesk@abusenoc.freshservice.com"],
            :additional_info => {:info => additional_info}
          })
    end
  end

  def notify_and_update(domain, vendor_id)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, nil, {
      :subject => "Error in creating mapping for a domain in sendgrid", 
      :recipients => "mail-alerts@freshdesk.com",
      :additional_info => {:info => "Domain already exists in sendgrid"}
      })

    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = { :url => post_url, :spam_check => false, :send_raw => true }
    response = send_request('patch', SendgridWebhookConfig::SENDGRID_API['update_url'] + domain, post_args)
    Rails.logger.info "Response message for sendgrid update action, Account id : #{Account.current.id}, code: #{response.code}, message: #{response.message}"
    webhook_key = AccountWebhookKey.find_by_account_id_and_vendor_id(Account.current.id, vendor_id)
    webhook_key.update_attributes(:webhook_key => generated_key) if webhook_key.present?
  end

  def send_request(action, url, post_args={})
    Timeout::timeout(TIMEOUT) do
      response = HTTParty.safe_send(action, url, :body => post_args.to_json, 
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
    set_others_redis_key(key,args.to_json,3888000)
    increment_portal_cache_version
  end

  def increment_portal_cache_version
    return if get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false"
    Rails.logger.debug "::::::::::Sweeping from portal"
    key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
    increment_portal_redis_version key
  end

end

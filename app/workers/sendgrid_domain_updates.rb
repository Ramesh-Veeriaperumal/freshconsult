require 'resolv'

class SendgridDomainUpdates < BaseWorker

  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis

  require 'freemail'

  TIMEOUT = SendgridWebhookConfig::CONFIG[:timeout]

  sidekiq_options :queue => :sendgrid_domain_updates, :retry => 3, :backtrace => true, :failures => :exhausted

  def perform(args)
    begin 
      unless args['action'].blank?
        domain_in_sendgrid = sendgrid_domain_exists?(args['domain'])
        if (!domain_in_sendgrid && args['action'] == 'delete')
          Rails.logger.info "Domain #{args['domain']} does not exist in sendgrid to delete"
        elsif (domain_in_sendgrid && args['action'] == 'create')
          notify_and_update(args['account_id'], args['domain'], args['vendor_id'])
        elsif (args['action'] == 'create' or args['action'] == 'delete')
          self.send("#{args['action']}_record", args['account_id'], args['domain'], args['vendor_id'])
        end
      end
    rescue => e
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => args['domain']}, e, {
        :subject => "Error in updating domain in sendgrid", 
        :recipients => "mail-alerts@freshdesk.com" 
        })
    end
  end

  def sendgrid_domain_exists?(domain)
    response = send_request('get', SendgridWebhookConfig::SENDGRID_API['get_specific_domain_url'] + domain)
    return true if response.code == 200
  end

  def delete_record(account_id, domain, vendor_id)
    response = send_request('delete', SendgridWebhookConfig::SENDGRID_API["delete_url"] + domain)
    return false unless response.code == 204
    Rails.logger.info "Deleting domain #{domain} from sendgrid"
    AccountWebhookKey.destroy_all(account_id: account_id, vendor_id: vendor_id)
  end

  def create_record(account_id, domain, vendor_id)
    generated_key = generate_callback_key
    check_spam_account(account_id)
    post_url = SendgridWebhookConfig::POST_URL % { :protocol => get_protocol(domain), :full_domain => domain, :key => generated_key }
    post_args = {:hostname => domain, :url => post_url, :spam_check => false, :send_raw => false }
    response = send_request('post', SendgridWebhookConfig::SENDGRID_API["set_url"] , post_args)
    return false unless response.code == 200
    verification = AccountWebhookKey.new(:account_id => account_id, 
      :webhook_key => generated_key, :vendor_id => vendor_id, :status => 1)
    verification.save!
  end

  def check_spam_account(account_id)
    account = Account.find_by_id(account_id)
    if account.present?
      admin_email_domain = parse_email_with_domain(account.admin_email)[:domain]
      resolver = Resolv::DNS.new
      mxrecord = resolver.getresources(admin_email_domain,Resolv::DNS::Resource::IN::MX) if admin_email_domain.present?
      
      spam_email_exact_regex_value = get_others_redis_key(SPAM_EMAIL_EXACT_REGEX_KEY)
      spam_email_apprx_regex_value = get_others_redis_key(SPAM_EMAIL_APPRX_REGEX_KEY)
      spam_email_exact_match_regex = spam_email_exact_regex_value.present? ? Regexp.compile(spam_email_exact_regex_value, true) : SPAM_EMAIL_EXACT_REGEX
      spam_email_apprx_match_regex = spam_email_apprx_regex_value.present? ? Regexp.compile(spam_email_apprx_regex_value, true) : SPAM_EMAIL_APPRX_REGEX

      if( mxrecord.blank? || (ismember?(BLACKLISTED_SPAM_DOMAINS,admin_email_domain)) || 
          ((account.helpdesk_name =~ spam_email_exact_match_regex || account.full_domain =~ spam_email_exact_match_regex) && Freemail.free_or_disposable?(account.admin_email)))
        add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, account_id)
        add_member_to_redis_set(BLACKLISTED_SPAM_ACCOUNTS, account_id)
        FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
          :subject => "Detected suspicious spam account :#{account_id} ", 
          :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com"],
          :additional_info => {:info => "Outgoing may be blocked for Account ID: #{account_id} , Reason: Account's contact address is invalid or its domain is blacklisted or Account name is suspicious "}
        })
      elsif((account.helpdesk_name =~ spam_email_apprx_match_regex || account.full_domain =~ spam_email_apprx_match_regex) && Freemail.free_or_disposable?(account.admin_email)) 
        add_member_to_redis_set(BLACKLISTED_SPAM_ACCOUNTS, account_id)
        FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
          :subject => "Detected suspicious spam account :#{account_id} ", 
          :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com"],
          :additional_info => {:info => "Account ID: #{account_id} , Reason: Account name looks suspicious"}
        })
      end
    end
  end

  def notify_and_update(account_id, domain, vendor_id)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, nil, {
      :subject => "Error in creating mapping for a domain in sendgrid", 
      :recipients => "mail-alerts@freshdesk.com",
      :additional_info => {:info => "Domain already exists in sendgrid"}
      })

    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :protocol => get_protocol(domain), :full_domain => domain, :key => generated_key }
    post_args = { :url => post_url, :spam_check => false, :send_raw => false }
    response = send_request('patch', SendgridWebhookConfig::SENDGRID_API['update_url'] + domain, post_args)
    AccountWebhookKey.find_by_account_id_and_vendor_id(account_id, vendor_id).update_attributes(:webhook_key => generated_key)
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

  def get_protocol(domain)
    multi_level_domain = domain.gsub(/.freshdesk.com/, "")
    domain_level_count = multi_level_domain.split('.').count
    (domain_level_count > 1 ? "http" : "https" )
  end

end

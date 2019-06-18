class AccountInfoToDynamo < BaseWorker

  include EmailHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  SKIP_NOTIFICIATION_DOMAINS = ["freshdesk.com"]

  sidekiq_options :queue => :account_info_to_dynamo, :retry => 2, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @args    = args
    @account = Account.current
    add_account_info_to_dynamo @args[:email], @account.id, @account.created_at.getutc
    check_associated_account_count @args[:email]

    # restricted_domains = $redis_others.lrange("SIGNUP_RESTRICTED_DOMAINS", 0, -1)
    domain = @args[:email].split("@").last
    if ismember?(SIGNUP_RESTRICTED_EMAIL_DOMAINS, domain)
      #@account.subscription.update_attributes(:state => "suspended", :next_renewal_at => Time.now - 10.days)
      ShardMapping.find_by_account_id(@account.id).update_attributes(:status => 403)

      subject = "Account blocked - Account id : #{@account.id}"
      additional_info = "Customer's admin email domain is restricted from account signup"
      notify_account_blocks(@account, subject, additional_info)
      update_freshops_activity(@account, "Account blocked during signup due to restricted domain", "block_account")
            
      Rails.logger.info "Suspending account #{@account.id}"
    else
      Rails.logger.info "Not Suspending account #{@account.id}"    
    end

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

  def check_associated_account_count email
    associated_accounts = AdminEmail::AssociatedAccounts.find email
    if associated_accounts.count > AdminEmail::AssociatedAccounts::MAX_ACCOUNTS_COUNT
      raise_notification email, associated_accounts
    end
  end

  def add_account_info_to_dynamo email, account_id, time_stamp
    AdminEmail::AssociatedAccounts.update email, account_id, time_stamp
  end

  def remove_account_info_to_dynamo email, account_id, time_stamp
    AdminEmail::AssociatedAccounts.remove email, account_id, time_stamp
  end

  private

    def skip_notification? email
      email_domain = email.split('@')[1]
      SKIP_NOTIFICIATION_DOMAINS.include? email_domain
    end

    def raise_notification email, accounts_list
      return if skip_notification? email
      notification_topic = SNS["dev_ops_notification_topic"]
      subject = "Accounts limit exceed for email : #{email}"
      options = { email: email, accounts_list: accounts_list, environment: Rails.env }
      DevNotification.publish(notification_topic, subject, options.to_json)
    end
end

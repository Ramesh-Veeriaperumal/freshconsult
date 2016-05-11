class AccountInfoToDynamo < BaseWorker

  sidekiq_options :queue => :account_info_to_dynamo, :retry => 2, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @args    = args
    @account = Account.current
    add_account_info_to_dynamo @args[:email], @account.id, @account.created_at.getutc
    check_associated_account_count @args[:email]
  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

  private

    def add_account_info_to_dynamo email, account_id, time_stamp
      AdminEmail::AssociatedAccounts.new email, account_id, time_stamp
    end

    def check_associated_account_count email
      associated_accounts = AdminEmail::AssociatedAccounts.find email
      if associated_accounts.count > AdminEmail::AssociatedAccounts::MAX_ACCOUNTS_COUNT
        raise_notification email, associated_accounts
      end
    end

    def raise_notification email, accounts_list
      notification_topic = SNS["dev_ops_notification_topic"]
      subject = "Accounts limit exceed for email : #{email}"
      options = { email: email, accounts_list: accounts_list, environment: Rails.env }
      DevNotification.publish(notification_topic, subject, options.to_json)
    end
end

class CRM::AddToCRM
  QUEUE = "salesforceQueue"
  
  class Customer
    extend Resque::AroundPerform

    def self.perform(args)
      item = scoper.find_by_account_id_and_id(Account.current.id,args[:item_id])
      # crm = CRM::Salesforce.new
      crm = ""
      perform_job(crm, item) if (Rails.env.production? or Rails.env.staging?)
    end
  end

  class PaidCustomer < Customer
    @queue = QUEUE

    def self.scoper
      SubscriptionPayment
    end

    def self.perform_job(crm, item)
      # crm.add_paid_customer_to_crm(item)
    end
  end

  class FreeCustomer < Customer
    @queue = QUEUE

    def self.scoper
      Subscription
    end

    def self.perform_job(crm, item)
      # crm.add_free_customer_to_crm(item)
    end
  end

  class DeletedCustomer 
    extend Resque::AroundPerform
    @queue = QUEUE

    def self.perform(account_id)
      ThirdCRM.new.mark_as_deleted_customer
    ensure
      CRM::FreshsalesUtility.new({ account: Account.current }).account_cancellation if (Rails.env.production? or Rails.env.staging?)
    end
  end

  class UpdateAdmin < Customer
    @queue = QUEUE

    def self.scoper
      AccountConfiguration
    end

    def self.perform_job(crm, item)
      # crm.update_admin_info(item)
    ensure
      Resque.enqueue(CRM::Freshsales::AdminUpdate, { :account_id => Account.current.id })
    end
  end

  class UpdateTrialAccounts
    extend Resque::AroundPerform
    @queue = QUEUE

    def self.perform(args)
      # Do not enqueue jobs for paying and free customers. Temporary fix to discard those jobs 
      # in the queue
      account = Account.current
      return if account.subscription.active? or account.subscription.free?

      # CRM::Salesforce.new.update_trial_accounts(Account.current.id) if Rails.env.production?
    end
  end

  class UpdateCustomerStatus
    extend Resque::AroundPerform
    @queue = QUEUE
    def self.perform(args)
      # CRM::Salesforce.new.update_customer_status if Rails.env.production?
    end
  end

end

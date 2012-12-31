class CRM::AddToCRM
  QUEUE = "salesforceQueue"
  
  class Customer
    # def initialize
    #   @queue = QUEUE
    # end

    def self.perform(item_id)
      item = scoper.find(item_id)
      crm = CRM::Salesforce.new
      perform_job(crm, item)
    end
  end

  class PaidCustomer < Customer
    @queue = QUEUE

    def self.scoper
      SubscriptionPayment
    end

    def self.perform_job(crm, item)
      crm.add_paid_customer_to_crm(item)
    end
  end

  class FreeCustomer < Customer
    @queue = QUEUE

    def self.scoper
      Subscription
    end

    def self.perform_job(crm, item)
      crm.add_free_customer_to_crm(item)
    end
  end

  class DeletedCustomer 
    @queue = QUEUE

    def self.perform(account_id)
      CRM::Salesforce.new.update_deleted_account_to_crm(account_id)
    end
  end

  class UpdateAdmin < Customer
    @queue = QUEUE

    def self.scoper
      User
    end

    def self.perform_job(crm, item)
      crm.update_admin_info(item)
    end
  end

 end



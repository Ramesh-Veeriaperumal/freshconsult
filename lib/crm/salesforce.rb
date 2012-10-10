class CRM::Salesforce < Resque::Job
  
  include ErrorHandle 

  BUSINESS_TYPES = { :new =>  "New Business", :existing => "Existing Business" }
  
  PAYMENT_TYPE = "Credit Card"

  STAGE_NAME = "Closed Won"

  CUSTOMER_STATUS = { :free => "Free", :paid => "Customer" }

  ACCOUNT_ATTR = { :accountId => :salesforce_id, :Type => :business_type }

  PAYMENT_ATTR = { :Name => :to_s, :Agents__c => :agents, :Plan__c => :plan_name, 
                   :Discount__c => :discount, :Amount => :amount }

	def initialize
    username = AppConfig['salesforce'][RAILS_ENV]['username']
    password = AppConfig['salesforce'][RAILS_ENV]['password']
    binding.login(username, password)
	end

  def add_paid_customer_to_crm(payment)
    returned_value = sandbox(0){
      account_attr = account_attributes(payment)
      payment_attr = payment_attributes(payment)
      opportunity_attr = opportunity_attributes
      record = payment_attr.merge(account_attr)
      record = record.merge(opportunity_attr)
      add_opportunity(record)
      
      response = binding.update('sObject {"xsi:type" => "Account"}' => 
        { :id => record[:accountId] , :Customer_Status__c => CUSTOMER_STATUS[:paid] })
    }

    FreshdeskErrorsMailer.deliver_error_in_crm!(payment) if returned_value == 0
  end

  def add_free_customer_to_crm(subscription) 
    binding.update('sObject {"xsi:type" => "Account"}' => 
        { :id => salesforce_id(subscription) , :Customer_Status__c => CUSTOMER_STATUS[:free] })
  end  

  private 

    def binding
      @binding ||= begin
        RForce::Binding.new('https://www.salesforce.com/services/Soap/u/20.0')
      end
    end

    def account_attributes(payment)
      account_attr = ACCOUNT_ATTR.inject({}) { |h, (k, v)| h[k] = send(v, payment); h }
    end

    def payment_attributes(payment)                      
      payment_attr = PAYMENT_ATTR.inject({}) { |h, (k, v)| h[k] = payment.send(v).to_s; h }
    end

    def opportunity_attributes
      {
        :Payment_Tye__c => PAYMENT_TYPE,
        :StageName => STAGE_NAME,
        :Status__c => CUSTOMER_STATUS[:paid],
        :CloseDate =>  Time.now.to_s(:db)
      }
    end

    def add_opportunity(record)
      response = binding.create('sObject {"xsi:type" => "Opportunity"}' => record)
      result = response.createResponse.result
      
      raise Excpetion.new(result.errors.message) unless result.success
    end

    def salesforce_id(object)
      account = object.respond_to?(:account) ? object.account : object
      search_query = %(FIND {#{account.full_domain}} IN NAME FIELDS RETURNING Account(id))
      query = binding.search(:searchString => search_query)
      result = query.searchResponse.result
      id = result.searchRecords.record.Id
      
      (id.is_a?(Array))? id[0] : id
    end

    def business_type(payment)
      return BUSINESS_TYPES[:existing] if payment.misc? 
      
      (payment.account.subscription_payments.length > 1) ? BUSINESS_TYPES[:existing] : 
        BUSINESS_TYPES[:new] 
    end

end

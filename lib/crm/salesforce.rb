class CRM::Salesforce
  
  include ErrorHandle 

  BUSINESS_TYPES = { :new =>  "New Business", :existing => "Existing Business" }
  
  PAYMENT_TYPE = "Credit Card"

  STAGE_NAME = "Closed"

  ACCOUNT_ATTR = { :accountId => :account_id, :Type => :business_type }

  PAYMENT_ATTR = { :Name => :to_s, :Agents__c => :agents, :Plan__c => :plan_name, 
                   :Discount__c => :discount, :Amount__c => :amount, :Amount => :amount }

	def initialize
    username = AppConfig['salesforce'][RAILS_ENV]['username']
    password = AppConfig['salesforce'][RAILS_ENV]['password']
    binding.login(username, password)
	end

  def add_data_to_crm(payment)
    returned_value = sandbox(0){
      account_attr = account_attributes(payment)
      payment_attr = payment_attributes(payment)
      opportunity_attr = opportunity_attributes
      record = payment_attr.merge(account_attr)
      record = record.merge(opportunity_attr)
      add_opportunity(record)
    }

    FreshdeskErrorsMailer.deliver_error_in_crm!(payment) if returned_value == 0
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
        :CloseDate =>  Time.now.to_s(:db)
      }
    end

    def add_opportunity(record)
      response = binding.create('sObject {"xsi:type" => "Opportunity"}' => record)
      result = response.createResponse.result
      
      raise Excpetion.new(result.errors.message) unless result.success
    end

    def account_id(payment)
      # search_query = %(FIND {#{payment.account.name}} IN NAME FIELDS RETURNING Account(id WHERE 
      #   domain__c ='#{payment.account.full_domain}'))
      search_query = %(FIND {#{payment.account.full_domain}} IN NAME FIELDS RETURNING Account(id))
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

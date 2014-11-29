class CRM::Salesforce < Resque::Job
  
  include ErrorHandle 

  RECORD_TYPES        =   { :account => "Account", :contact => "Contact", :opportunity => "Opportunity",
                            :opportunity_contact_role => "OpportunityContactRole" }

  PAYMENT_ATTRIBUTES  =   { :Agents__c => :agents, :Plan__c => :plan_name, 
                            :Amount__c => :usd_equivalent, :Amount => :usd_equivalent, 
                            :Renewal_Period__c => :renewal_period }

  CRM_IDS             =   { :account => :AccountId, :contact => :Id }

  BUSINESS_TYPES      =   { :new =>  "New Business", :existing => "Existing Business - Renewal",
                            :misc => "Existing Business - Upgrade", :day_pass => "Day Pass" }

  CUSTOMER_STATUS     =   { :trial => "Trial", :suspended => "Trial Expired", :free => "Free", 
                            :paid => "Customer", :deleted => "Deleted",  }
  
  PAYMENT_TYPE        =   "Credit Card"

  STAGE_NAME          =   "Closed Won"


  def initialize
    binding.login_with_oauth
  end

  def add_paid_customer_to_crm(payment)
    #returned_value = sandbox(0){
      crm_ids = search_crm_record(payment.account_id)
      update_paid_account(crm_ids, payment)   
      
      return if business_type(payment).eql?(BUSINESS_TYPES[:existing])
      opportunity_id = add_opportunity(crm_ids, payment)
    #}
    #FreshdeskErrorsMailer.deliver_error_in_crm!(payment) if returned_value == 0
  end

  def add_free_customer_to_crm(subscription) 
    account = Account.current
    crm_ids = search_crm_record(account.id)
    update_account(crm_ids, account.full_domain, CUSTOMER_STATUS[:free])
  end

  def update_deleted_account_to_crm(account_id)
    crm_ids = search_crm_record(account_id)
    update_account(crm_ids, account_id, CUSTOMER_STATUS[:deleted])
  end

  def update_admin_info(config)
    crm_ids = search_crm_record(config.account.id)
    binding.update('sObject {"xsi:type" => "Contact"}' => { :id => crm_ids[:contact],
        :FirstName => config.account.admin_first_name, :LastName => config.account.admin_last_name, 
        :Email => config.account.admin_email, :Phone => config.account.admin_phone })
  end

  def account_owner(account_id)
    owner = nil

    search_string = %(SELECT Contact.Account.Owner.Name, Contact.Account.Owner.Email, Reseller__c, 
      Marketo_Contacted__c FROM Contact WHERE Freshdesk_Account_Id__c = '#{account_id}')
    response = binding.query(:searchString => search_string).queryResponse

    unless response.nil?
      result = response.result.records       
      owner  = result.Account.Owner unless discard_owner?(result)
    end

    owner
  end

  # Updates accounts/contacts in SFDC when trial extended or full time agents added.
  def update_trial_accounts(account_id)
    account = Account.current
    crm_ids = search_crm_record(account_id)
    next_renewal_date = account.subscription.next_renewal_at.to_s(:db)
    agent_count = account.full_time_agents.count.to_s
    
    record_attributes = { :Customer_Status__c => CUSTOMER_STATUS[:trial], 
      :Account_Renewal_Date__c => next_renewal_date,
      :Agent_Count__c => agent_count }

    [:account, :contact].each do |record|
      record_attributes.merge!({:id => crm_ids[record]})
      update_records_for_trial_accounts(RECORD_TYPES[record], record_attributes)
    end
  end

  private 

    def binding
      @binding ||= begin
        RForce::Binding.new('https://www.salesforce.com/services/Soap/u/20.0', nil, oauth_keys)
      end
    end

    def oauth_keys
      {
        :consumer_key    => AppConfig['salesforce'][Rails.env]['consumer_key'],
        :consumer_secret => AppConfig['salesforce'][Rails.env]['consumer_secret'],
        :access_token    => AppConfig['salesforce'][Rails.env]['access_token'],
        :access_secret   => AppConfig['salesforce'][Rails.env]['access_secret'],
        :login_url       => 'https://login.salesforce.com/services/OAuth/u/20.0'
      }
    end

    def search_crm_record(account_id)
      search_string = %(SELECT Id, AccountId FROM Contact WHERE Freshdesk_Account_Id__c = '#{account_id}')
      response = binding.query(:searchString => search_string).queryResponse

      return create_new_crm_account(Account.current) if response.result[:size].eql?("0")

      record = (response.result.records.is_a?(Array))? response.result.records[0] : response.result.records
      
      crm_ids = CRM_IDS.inject({}) { |h, (k, v)| 
                  h[k] = (id = record[v]).is_a?(Array)? id[0] : id ; h } 
    end

    #If record not found in CRM, new account and contact are added.
    def create_new_crm_account(account)  
      crm_ids = {}
      crm_ids[:account] = add_record(RECORD_TYPES[:account], { :name => account.full_domain })
      
      contact_info = account_attributes(account).merge(contact_attributes(account, crm_ids[:account]))
      crm_ids[:contact] = add_record(RECORD_TYPES[:contact], contact_info)
      crm_ids         
    end

    def add_record(record_type, record_info)
      query = create_crm_record(record_type, record_info)
      query.createResponse.result[:id]
    end

    def add_opportunity(crm_ids, payment)
      opportunity_id = fetch_opportunity(crm_ids[:account])
      data = opportunity_details(crm_ids, payment)
      if opportunity_id
        data.merge!({:id => opportunity_id})
        binding.update('sObject {"xsi:type" => "Opportunity"}' => data)
      else
        data.merge!(:Name => payment.account.name)
        opportunity_id = add_record(RECORD_TYPES[:opportunity], data)
        add_opportunity_contact_role(opportunity_id, crm_ids[:contact])
      end  
      opportunity_id
    end

    def add_opportunity_contact_role(opportunity_id, crm_contact_id)
      record = { :ContactId => crm_contact_id, :OpportunityId => opportunity_id }
      create_crm_record(RECORD_TYPES[:opportunity_contact_role], record)
    end

    def update_paid_account(crm_ids, payment)
      record = account_details(crm_ids[:account], payment)
      binding.update('sObject {"xsi:type" => "Account"}' => record)

      subscription = payment.account.subscription
      binding.update('sObject {"xsi:type" => "Contact"}' => { :id => crm_ids[:contact],
        :Account_Renewal_Date__c => subscription.next_renewal_at,
        :Customer_Status__c => CUSTOMER_STATUS[:paid], :Monthly_Revenue__c => subscription.cmrr.to_s,
        :Agent_Count__c => subscription.agent_limit.to_s })
    end

    def update_account(crm_ids, domain, status)
      binding.update('sObject {"xsi:type" => "Account"}' => 
        { :id => crm_ids[:account] , :name => domain, :Customer_Status__c => status })
      binding.update('sObject {"xsi:type" => "Contact"}' => 
        { :id => crm_ids[:contact], :Customer_Status__c => status })
    end

    def create_crm_record(record_type, record_attributes)
      sobject_type = %(sObject { 'xsi:type' => '#{record_type}' })
      binding.create(sobject_type => record_attributes)
    end

    def account_details(crm_account_id, payment)
      account_info = account_attributes(payment.account)
      payment_info = payment_attributes(payment).delete_if{|k, v| [:Name, :Amount].include? k }
      record = { :id => crm_account_id, :Name => payment.account.name, 
                  :Customer_Status__c => CUSTOMER_STATUS[:paid], :Agent_Count__c => payment.agents.to_s }

      record.merge(payment_info.merge(account_info))
    end

    def opportunity_details(crm_ids, payment)
      ((payment_attributes(payment)).merge(opportunity_attributes(payment))).merge(
        { :AccountId => crm_ids[:account], 
          :Type => business_type(payment), 
          :OwnerId => opportunity_owner(crm_ids) })
    end

    def account_attributes(account)
      {
        :Freshdesk_Domain_Name__c => account.full_domain,
        :Freshdesk_Account_Id__c => account.id.to_s,
        :Account_Created_Date__c => account.created_at.to_s(:db),
        :Account_Renewal_Date__c => account.subscription.next_renewal_at.to_s(:db)
      }
    end

    def contact_attributes(account, crm_account_id)
      { 
        :FirstName => account.admin_first_name,
        :LastName => account.admin_last_name,
        :Email => account.admin_email,
        :AccountId => crm_account_id
      }
    end

    def payment_attributes(payment)
      # return { :Name => payment.to_s } unless DayPassPurchase.find_by_payment_id(payment.id).blank?
      payment_attr = PAYMENT_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = payment.send(v).to_s; h } 
    end

    def opportunity_attributes(payment)
      {
        :Payment_Tye__c => PAYMENT_TYPE,
        :StageName => STAGE_NAME,
        :Status__c => CUSTOMER_STATUS[:paid],
        :CloseDate =>  Time.now.to_s(:db),
        :CMRR__c => payment.subscription.cmrr.to_s
      }
    end

    def business_type(payment)
      # return BUSINESS_TYPES[:day_pass] if DayPassPurchase.find_by_payment_id(payment.id)

      return BUSINESS_TYPES[:existing] if payment.misc?
      
      payments = payment.account.subscription_payments.collect{ |p| p unless p.misc }.compact
      (payments.length > 1) ? BUSINESS_TYPES[:existing] : BUSINESS_TYPES[:new] 
    end

    def opportunity_owner(crm_ids)
      begin
        search_string = %(SELECT OwnerId FROM Contact WHERE Id = '#{crm_ids[:contact]}')
        binding.query(:searchString => search_string).queryResponse.result.records.OwnerId
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    def discard_owner?(owner) # for below condition the salesforce account manager details should not be shown
      owner.nil? || owner.Reseller__c.to_bool || (owner.Marketo_Contacted__c == "Yes")
    end

    def fetch_opportunity(crm_account_id)
      begin
        search_query = %(SELECT Id FROM Opportunity WHERE AccountId = '#{crm_account_id}')
        response = binding.query(:searchString => search_query).queryResponse
        record = (response.result.records.is_a?(Array))? response.result.records[0] : response.result.records
        record[:Id].is_a?(Array)? record[:Id][0] : record[:Id]
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    def update_records_for_trial_accounts(record_type, record_attributes)      
      sobject_type = %(sObject { 'xsi:type' => '#{record_type}' })
      binding.update(sobject_type => record_attributes)
    end
end

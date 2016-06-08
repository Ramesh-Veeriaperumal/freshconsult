module SalesforceHelper

  def contact_fields_response
    { "fields" => [{"label"=>"Full Name", "name"=>"Name"}, {"label"=>"Contact ID", "name"=>"Id"}, {"label"=>"Email", "name"=>"Email"}] }
  end

  def account_fields_response
    { "fields" => [{"label"=>"Account Name", "name"=>"Name"}, {"label"=>"Account ID", "name"=>"Id"}, {"label"=>"Account Phone", "name"=>"Phone"}] }
  end

  def lead_fields_response
    { "fields" => [{"label"=>"Full Name", "name"=>"Name"}, {"label"=>"Lead ID", "name"=>"Id"}, {"label"=>"Email", "name"=>"Email"}] }
  end

  def opportunity_fields_response
    { "fields" => [{"label"=>"Name", "name"=>"Name"}, {"label"=>"Close Date", "name"=>"CloseDate"}, {"label"=>"Stage", "name"=>"StageName", "picklistValues" => [{"label"=>"Prospecting", "value"=>"Prospecting"}, {"label"=>"Qualification", "value"=>"Qualification"}, {"label"=>"Closed Won", "value"=>"Closed Won"}, {"label"=>"Closed Lost", "value"=>"Closed Lost"}]}] }
  end

  def app_configs
    { "app_name" => "salesforce", "oauth_token" => "XXXXXXXXXX", "instance_url" => "https://ap2.salesforce.com", "refresh_token" => "XXXXXXXXXX" }
  end

  def default_inst_app_params
    { 
      :contacts => ["Name"], :contact_labels => "Full Name",
      :accounts => ["Name"], :account_labels => "Name",
      :leads => ["Name"], :lead_labels => "Full Name",
      :opportunity_view => { :value => "0"}
    }
  end

  def default_inst_app_configs
    { 
      "contact_fields" => "Name", "contact_labels" => "Full Name",
      "account_fields" => "Name", "account_labels" => "Name",
      "lead_fields" => "Name", "lead_labels" => "Full Name",
      "opportunity_view" => "0"
    }
  end

  def enable_sync_feature(account)
    unless account.features?(:salesforce_sync)
      account.features.salesforce_sync.create
    end
    account
  end

  def disable_sync_feature(account)
    if account.features?(:salesforce_sync)
      account.features.salesforce_sync.destroy
      account.features.reload
    end
    account
  end

  def create_va_rules(inst_app)
    [["create", "create ticket"],["update", "update ticket"]].each do |sync_event|
      app_rule = inst_app.account.va_rules.build(
          :rule_type => 13,
          :name => "salesforce_ticket_#{sync_event[0]}_sync",
          :description => sync_event[1],
          :match_type => "any",
          :filter_data => 
            { :performer => {:type => "3" }, 
              :events => [{ :name => "ticket_action",:value => sync_event[0] }], 
              :conditions => [] },
          :action_data => [
            { :name => "Integrations::SyncHandler",
              :value => "execute",
              :service => "salesforce",
              :event => "#{sync_event[0]}_custom_object"
          }
          ],
          :active => true
        )
        
        app_rule.build_app_business_rule(
          :application => inst_app.application,
          :account_id => inst_app.account_id,
          :installed_application => inst_app
        )
        app_rule.save!
    end
  end 

end


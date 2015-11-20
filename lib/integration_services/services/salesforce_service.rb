module IntegrationServices::Services
  class SalesforceService < IntegrationServices::Service
  TICKET_SYNC_EVENTS = [["create", "This rule will create a freshdesk ticket in Salesforce."],
                        ["update", "This rule will update a freshdesk ticket in Salesforce."]]

  TICKET_FIELDS = [["Name", "display_id"], ["freshdesk__TicketID__c", "id"],["freshdesk__TicketSubject__c", "subject"],
   ["freshdesk__TicketType__c", "ticket_type"], ["freshdesk__CreatedAt__c", "created_at"], ["freshdesk__UpdatedAt__c", "updated_at"]]

  TICKET_STATES = [["freshdesk__AgentRespondedAt__c", "agent_responded_at"], ["freshdesk__AssignedAt__c", "assigned_at"], 
  ["freshdesk__AverageResponseTime__c", "avg_response_time"], ["freshdesk__AverageResponseTimeBusiness__c", "avg_response_time_by_bhrs"], 
  ["freshdesk__ClosedAt__c", "closed_at"], ["freshdesk__FirstAssignedAt__c", "first_assigned_at"], 
  ["freshdesk__FirstResponseTime__c", "first_response_time"], ["freshdesk__FirstResponseTimeBusiness__c", "first_resp_time_by_bhrs"], 
  ["freshdesk__GroupEscalated__c", "group_escalated"], ["freshdesk__InboundCount__c", "inbound_count"], 
  ["freshdesk__OpenedAt__c", "opened_at"], ["freshdesk__OutboundCount__c", "outbound_count"], ["freshdesk__PendingSince__c", "pending_since"], 
  ["freshdesk__RequesterRespondedAt__c", "requester_responded_at"], ["freshdesk__ResolutionTimeBusiness__c", "resolution_time_by_bhrs"], 
  ["freshdesk__ResolvedAt__c", "resolved_at"], ["freshdesk__SLATimerStoppedAt__c", "sla_timer_stopped_at"], ["freshdesk__StatusUpdatedAt__c", "status_updated_at"]]


  FD_COMPANY = "FRESHDESK_UNKNOWN_COMPANY"
  CONTACT_CUSTOM_FIELDS = ["freshdesk__Freshdesk_Twitter_UserName__c", "freshdesk__Freshdesk_Facebook_Id__c", "freshdesk__Freshdesk_External_Id__c"]
  CONTACT_FIELDS = ["Email", "MobilePhone", "Phone", "freshdesk__Freshdesk_Twitter_UserName__c", 
    "freshdesk__Freshdesk_Facebook_Id__c", "freshdesk__Freshdesk_External_Id__c"]
    def self.title
      "salesforce"
    end

    def instance_url
      self.configs['instance_url']
    end    

    def receive_install      
      TICKET_SYNC_EVENTS.each do |sync_evt|
        app_rule = @installed_app.account.va_rules.build(
          :rule_type => VAConfig::API_WEBHOOK_RULE,
          :name => "salesforce_ticket_#{sync_evt[0]}_sync",
          :description => sync_evt[1],
          :match_type => "any",
          :filter_data => 
            { :performer => {:type => ApiWebhooks::Constants::PERFORMER_ANYONE }, 
              :events => [{ :name => "ticket_action",:value => sync_evt[0] }], 
              :conditions => [] },
          :action_data => [
            { :name => "Integrations::SyncHandler",
              :value => "execute",
              :service => "salesforce",
              :event => "#{sync_evt[0]}_custom_object"
          }
          ],
          :active => true
        )
        
        app_rule.build_app_business_rule(
          :application => @installed_app.application,
          :account_id => @installed_app.account_id,
          :installed_application => @installed_app
        )
        app_rule.save!
      end
    end

    def receive_create_custom_object
      co_attributes, co_custom_fields, ticket_id = perform_api_actions "create"
      create_res = custom_object_resource.create co_attributes
      update_res = update_custom_fields co_custom_fields, create_res["id"]
    end
    
    def receive_update_custom_object
      sf_ticket_det = custom_object_resource.find @payload[:data_object].id
      co_attributes, co_custom_fields, ticket_id = perform_api_actions "update", sf_ticket_det
      if sf_ticket_det["records"].present?
        object_id = sf_ticket_det["records"].first["Id"]
        update_res = custom_object_resource.update co_attributes, object_id
        update_res = update_custom_fields co_custom_fields, object_id
      else
        create_res = custom_object_resource.create co_attributes
        update_res = update_custom_fields co_custom_fields, create_res["id"]
      end
    end  

    def update_custom_fields co_custom_fields, object_id
      custom_object_resource.update co_custom_fields, object_id if co_custom_fields.present?
    end

    def receive_contact_fields
      contact_resource.get_fields
    end

    def receive_lead_fields
      lead_resource.get_fields
    end

    def receive_account_fields
      account_resource.get_fields
    end

    def receive_fetch_user_selected_fields
      send("#{@payload[:type]}_resource").get_selected_fields(@installed_app.send("configs_#{@payload[:type]}_fields"), @payload[:value])
    end

    def deactivate_ticket_sync!
      remove_sync_option
      @installed_app.va_rules.each do |x| 
        x.active = false
        x.save
      end
      @installed_app.save!
    end

    private

    def salesforce_sync_option?
      @installed_app.configs_salesforce_sync_option.to_s.to_bool
    end

    def remove_sync_option
      @installed_app.configs[:inputs]["salesforce_sync_option"] = "0"
    end

    def account_resource
      @account_resource ||= IntegrationServices::Services::Salesforce::SalesforceAccountResource.new(self)
    end

    def contact_resource
      @contact_resource ||= IntegrationServices::Services::Salesforce::SalesforceContactResource.new(self)
    end

    def lead_resource
      @lead_resource ||= IntegrationServices::Services::Salesforce::SalesforceLeadResource.new(self)
    end

    def custom_object_resource
      @custom_object_resource ||= IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.new(self)
    end

    def format_phone(number)
      ActionController::Base.helpers.number_to_phone(number, :area_code => true)
    end

    def perform_api_actions action, sf_ticket_det=nil
      ticket = @payload[:data_object] 
      co_attributes ={}
      fd_user = ticket.requester
      if action == "create" || sf_ticket_det["records"].blank?
        fd_comp_name = (ticket.requester.company.present?) ? ticket.requester.company.name : FD_COMPANY
        co_attributes = assign_contact_det fd_comp_name, fd_user
      end
      ticket_states = ticket.ticket_states
      co_attributes = assign_ticket_prop ticket, fd_user, co_attributes
      TICKET_STATES.each do |sf,fd|
        co_attributes[sf] = ticket_states.send(fd)
      end
      co_custom_fields = populate_custom_fields ticket
      [co_attributes, co_custom_fields, ticket.id]
    end

    def perform_contact_action query, fd_comp_name, fd_user, fd_contact
      deactivate_ticket_sync! if !custom_object_resource.check_fields_synced?(CONTACT_FIELDS.join(","), "Contact")
      contact_response = contact_resource.find query
      acc_name_for_sync = fd_comp_name
      if contact_response.present? && contact_response["records"].present?
        sf_con_det = contact_weightage_check contact_response["records"], fd_contact
        con_name_for_sync = sf_con_det["Name"]
        sf_con_id = sf_con_det["Id"]
        sf_account_id, acc_name_for_sync = sync_account sf_con_det, fd_comp_name
      else
        sf_account_id = create_sf_account fd_comp_name
        con_name_for_sync = fd_contact["LastName"] = fd_user.name
        fd_contact["AccountId"] = sf_account_id
        sf_con_det = create_sf_contact fd_contact
        sf_con_id = sf_con_det["id"]
      end
      [sf_account_id, sf_con_id, acc_name_for_sync, con_name_for_sync]
    end

    def contact_weightage_check records, fd_contact
      match = 0
      if records.size > 1
        contact_weights = [32, 16, 8, 4, 2, 1]
        weights = Hash[CONTACT_FIELDS.zip contact_weights]
        weight_rec= Array.new(records.size, 0)
        records.each_with_index do |rec, i|
          fd_contact.keys.each do |key|
            weight_rec[i] += weights[key] if rec[key] == fd_contact[key]
          end
        end
        match = weight_rec.index(weight_rec.max)
      end
      records[match]
    end

    def sync_account sf_con_det, fd_comp_name
      if sf_con_det["AccountId"].present? 
        sf_account_id  = sf_con_det["AccountId"]
        acc_name_for_sync = sf_con_det["Account"]["Name"]
        unless (fd_comp_name.downcase).eql? (sf_con_det["Account"]["Name"].downcase)
          unless fd_comp_name.eql? FD_COMPANY
            sf_account_id = create_sf_account fd_comp_name
            acc_name_for_sync = fd_comp_name
          end 
        end
      else          
        sf_account_id = create_sf_account fd_comp_name
        acc_name_for_sync = fd_comp_name
      end
      [sf_account_id, acc_name_for_sync]
    end

    def populate_custom_fields ticket
      co_custom_fields = {}
      fd_custom_fields = Account.current.ticket_fields.custom_fields
      fd_custom_fields = fd_custom_fields.reject{|x| (x.nested_field? || x.section_field?) }
      formatted_fields = sf_custom_fields(fd_custom_fields)
      return co_custom_fields if fd_custom_fields.blank?
      formatted_fields.each do |custom_field|
        fd_cust_field_value = ticket.send(custom_field[0])
        co_custom_fields[custom_field[1]] = fd_cust_field_value
      end
      co_custom_fields
    end

    def sf_custom_fields(fd_custom_fields)
      fd_custom_fields.map do |custom_field|
       [ custom_field.name , "#{custom_field.name.gsub(/_[0-9]+$/,'')}__c" ]
      end
    end

    def create_sf_contact fd_contact
      sf_con_det = contact_resource.create fd_contact
      raise RemoteError , "Error in creating new Salesforce Contact" unless sf_con_det["success"].eql? true
      sf_con_det
    end

    def create_sf_account fd_comp_name
      acc_exist =  account_resource.find fd_comp_name
      if acc_exist["records"].present?
        sf_account_det = acc_exist["records"].first
        acc_id = sf_account_det["Id"]
      else
        body = { "Name" => fd_comp_name}
        sf_account_det = account_resource.create body
        raise RemoteError , "Error in creating new Salesforce Account" unless sf_account_det["success"].eql? true
        acc_id = sf_account_det["id"]
      end
      acc_id
    end

    def assign_contact_det fd_comp_name, fd_user
      fd_contact = {}
      fd_det = ["email", "phone", "mobile", "twitter_id", "fb_profile_id", "external_id"]
      user_det = Hash[CONTACT_FIELDS.zip fd_det]
      user_det.each do |k, v|
        fd_contact[k] = (["phone", "mobile"].include? v)? format_phone(fd_user.send(v)) : fd_user.send(v) if fd_user.send(v).present? 
      end 
      query =  fd_contact.map{|k,v| "#{k}='#{v}'"}.join(' OR ')
      sf_account_id, sf_con_id, acc_name_for_sync, con_name_for_sync = perform_contact_action query, fd_comp_name, fd_user, fd_contact
      co_attributes = {}
      co_attributes["freshdesk__SalesforceAccount__c"] = sf_account_id
      co_attributes["freshdesk__SalesforceContact__c"] = sf_con_id
      co_attributes["freshdesk__RequesterName__c"] = con_name_for_sync
      co_attributes
    end

    def assign_ticket_prop ticket, fd_user, co_attributes
      co_attributes["freshdesk__RequesterEmail__c"] = fd_user.send("email")
      co_attributes["freshdesk__TicketPriority__c"] = TicketConstants::PRIORITY_NAMES_BY_KEY[ticket.priority].titlecase
      co_attributes["freshdesk__TicketSource__c"] = TicketConstants::SOURCE_TOKEN_BY_KEY[ticket.source].to_s.titlecase
      co_attributes["freshdesk__TicketProduct__c"] = (ticket.product.present?) ? ticket.product.name : nil
      co_attributes["freshdesk__TicketGroup__c"] = (ticket.group.present?) ? ticket.group.name : nil
      co_attributes["freshdesk__TicketTags__c"] = ticket.ticket_tags
      co_attributes["freshdesk__TicketDescription__c"] = ticket.description.truncate(32767)
      co_attributes["freshdesk__TicketStatus__c"]  = ticket.status_name
      co_attributes["freshdesk__AgentEmail__c"] = (ticket.responder.present?)? ticket.responder.email : nil
      co_attributes["freshdesk__AgentName__c"] = (ticket.responder.present?)? ticket.responder.name : nil
      if ticket.responder.present?
        user_response  = contact_resource.find_user "Email = '#{ticket.responder.email}'"
        co_attributes["freshdesk__SalesforceUser__c"] = user_response["records"].first["Id"] unless user_response["records"].blank?
      end       
      TICKET_FIELDS.each do |sf,fd|
        co_attributes[sf] = ticket.send(fd)
      end
      co_attributes
    end

  end
end
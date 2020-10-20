module IntegrationServices::Services
  class CloudElementsService < IntegrationServices::Service
    def self.title
      'cloud_elements'
    end
 
    def server_url 
      Integrations::CLOUD_ELEMENTS_URL
    end

     def self.default_http_options
      @@default_http_options ||= {
        :request => {:timeout => 90 , :open_timeout => 60},
        :ssl => {:verify => false, :verify_depth => 30},
        :headers => {}
      }
    end

    def receive_create_element_instance
      element_instance_resource.create_instance
    end

    def receive_delete_element_instance
      element_instance_resource.delete_instance
    end

    def receive_get_element_configuration
      element_instance_resource.get_configuration
    end

    def receive_update_element_configuration
      element_instance_resource.update_configuration
    end

    def receive_object_metadata
      safe_send("#{@payload[:object]}_resource").get_fields
    end

    def receive_create_instance_object_definition
      object_resource.create_instance_level_object_definition
    end

    def receive_update_instance_object_definition
      object_resource.update_instance_level_object_definition
    end

    def receive_create_instance_transformation
      transformation_resource.create_instance_level_transformation
    end

    def receive_update_instance_transformation
      transformation_resource.update_instance_level_transformation
    end

    def receive_create_formula_instance
      formula_resource.create_instance
    end

    def receive_update_formula_instance
      formula_resource.update_instance
    end

    def receive_delete_formula_instance
      formula_resource.delete_instance
    end

    def receive_get_formula_executions
      formula_resource.get_execution
    end

    def receive_get_formula_failure_step_id
      formula_resource.get_failure_step_id
    end

    def receive_get_formula_failure_reason
      formula_resource.get_failure_reason
    end

    def receive_get_contact_account_name
      account_resource.get_account_name @payload[:query]
    end

    def receive_get_contact_account_id
      contact_resource.get_selected_fields([], @payload[:email], @meta_data[:app_name])
    end

    def receive_fetch_user_selected_fields
      safe_send("#{@payload[:type]}_resource").get_selected_fields(@installed_app.safe_send("configs_#{@payload[:type]}_fields"), @payload[:value], @meta_data[:app_name])
    end

    def receive_integrated_resource
      return {} if @payload[:ticket_id].blank?
      super
    end

    def receive_create_opportunity
      begin
        integrated_local_resource = receive_integrated_resource
        return { :error => "Link failed.This ticket is already linked to an opportunity", :remote_id => integrated_local_resource["remote_integratable_id"] } unless integrated_local_resource.blank?
        @payload.delete(:type)
        @payload.delete(:ticket_id)
        opportunity_resource.create @payload, @meta_data[:app_name]
      rescue RemoteError => e
        return error(e.to_s, { :exception => e.status_code })
      end
    end

    def receive_link_opportunity
      begin
        integrated_local_resource = receive_integrated_resource
        return { :error => "Link failed.This ticket is already linked to an opportunity", :remote_id => integrated_local_resource["remote_integratable_id"] } unless integrated_local_resource.blank?
        @installed_app.integrated_resources.create(
          :remote_integratable_id => @payload[:remote_id],
          :remote_integratable_type => "opportunity",
          :local_integratable_id => @payload[:ticket_id],
          :local_integratable_type => "Helpdesk::Ticket",
          :account_id => @installed_app.account
        )
      rescue Exception => e
        return error("Error in linking the ticket with the salesforce opportunity", { :exception => e })
      end
    end

    def receive_unlink_opportunity
      begin
        integrated_resource = @installed_app.integrated_resources.where(
          :local_integratable_id => @payload[:ticket_id],
          :remote_integratable_id => @payload[:remote_id], 
          :remote_integratable_type => "opportunity"
        ).first
        return { :error => "The opportunity is already unlinked from the ticket", :remote_id => "" } if integrated_resource.blank?
        integrated_resource.destroy
      rescue Exception => e
        return error("Error in unlinking the ticket with the salesforce opportunity", { :exception => e })
      end
    end

    def receive_uninstall
      app_name = installed_app.application.name
      formula_details = {
        :freshdesk => { :id => installed_app.configs_helpdesk_to_crm_formula_instance, :template_id => Integrations::HELPDESK_TO_CRM_FORMULA_ID[app_name]}, 
        :hubs => {:id => installed_app.configs_crm_to_helpdesk_formula_instance, :template_id => Integrations::CRM_TO_HELPDESK_FORMULA_ID[app_name]}
      }

      formula_details.keys.each do |key|
        metadata = {:formula_template_id => formula_details[key][:template_id], :id => formula_details[key][:id]}
        options = {:metadata => metadata, :app_id => installed_app.application_id, :object => Integrations::CloudElements::Constant::NOTATIONS[:formula]}
        Integrations::CloudElementsDeleteWorker.new.perform(options)  
      end

      [installed_app.configs_element_instance_id, installed_app.configs_fd_instance_id].each do |element_id|
        options = {:metadata => {:id => element_id}, :app_id => installed_app.application_id, :object => Integrations::CloudElements::Constant::NOTATIONS[:element]}
        Integrations::CloudElementsDeleteWorker.perform_async(options)     
      end 
      Rails.logger.debug "#{app_name}: Formula and Element Instance Queuing for Delete done Successfully"
      rescue Exception => e
        error_log = "Account: #{Account.current.full_domain}, Id: #{Account.current.id}, #{app_name}: Error on Formula Instances delete. FD Formula Template ID:#{formula_details[:freshdesk][:template_id]}, 
          FD Formula Instance Id: #{formula_details[:freshdesk][:id]}, Element Formula Template ID:#{formula_details[:hubs][:template_id]}, Element Formula Instance Id: #{formula_details[:hubs][:id]},
          #{app_name} Instance Id: #{installed_app.configs_element_instance_id}, Freshdesk Instance Id: #{installed_app.configs_fd_instance_id}. Delete them Manually."
        NewRelic::Agent.notice_error(e, { custom_params: { description: error_log, account_id: Account.current.id }})
        FreshdeskErrorsMailer.error_email(nil, nil, e, {
          :subject => error_log, :recipients => AppConfig['integrations_email']
        })
    end

    private

    def cloud_elements_resource
      @cloud_elements_resource ||= IntegrationServices::Services::CloudElements::CloudElementsResource.new(self)
    end

    def element_instance_resource
      @element_instance_resource ||= IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.new(self)
    end

    def object_resource
      @object_resource ||= IntegrationServices::Services::CloudElements::Platform::ObjectResource.new(self)
    end

    def transformation_resource
      @transformation_resource ||= IntegrationServices::Services::CloudElements::Platform::TransformationResource.new(self)
    end

    def formula_resource
      @formula_resource ||= IntegrationServices::Services::CloudElements::Platform::FormulaResource.new(self)
    end

    def contact_resource
      @contact_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.new(self)
    end

    def account_resource
      @account_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.new(self)
    end

    def lead_resource
      @lead_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::LeadResource.new(self)
    end

    def opportunity_resource
      @opportunity_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::OpportunityResource.new(self)
    end

    def contract_resource
      @contract_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::ContractResource.new(self)
    end

    def order_resource
      @order_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::OrderResource.new(self)
    end

    def ticket_object_resource
      @ticket_object_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.new(self)
    end

  end

  class SalesforceV2Service < CloudElementsService
  #specifically for Salesforce Events 
    class TicketObjectNotFoundException < StandardError 
    end

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

    def receive_ticket_sync_install
      TICKET_SYNC_EVENTS.each do |sync_evt|
        app_rule = @installed_app.account.va_rules.build(
          :rule_type => VAConfig::API_WEBHOOK_RULE,
          :name => "salesforce_v2_ticket_#{sync_evt[0]}_sync",
          :description => sync_evt[1],
          :match_type => "any",
          :filter_data => 
            { :performer => {:type => ApiWebhooks::Constants::PERFORMER_ANYONE }, 
              :events => [{ :name => "ticket_action",:value => sync_evt[0] }], 
              :conditions => [] },
          :action_data => [
            { :name => "Integrations::SyncHandler",
              :value => "cloud_ticket_execute",
              :service => "salesforce_v2",
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
      # Ticket Create event
      raise TicketObjectNotFoundException if !ticket_object_resource.check_fields_synced? #checking freshdesk__Freshdesk_Ticket_Object__c exist or not.
      co_attributes, co_custom_fields, ticket_id = perform_api_actions "create" # Create Contact, Account If needed and also create the payload for create/update of the freshdesk ticket object.
      create_res = ticket_object_resource.create co_attributes
      update_res = update_custom_fields co_custom_fields, create_res["Id"]
    rescue TicketObjectNotFoundException => e
      deactivate_ticket_sync!
      Rails.logger.debug "freshdesk__Freshdesk_Ticket_Object__c is not found in Salesforce for this account. Error - #{error}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "freshdesk__Freshdesk_Ticket_Object__c is not found in Salesforce for this account. Error - #{error}", :account_id => Account.current.id}})    
    rescue => e 
      Rails.logger.debug "Error in Creating the Salesforce Ticket Object: #{e.message}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error in Creating the Salesforce Ticket Object: #{e.message}", :account_id => Account.current.id}})
    end

    def receive_update_custom_object
      # Ticket Update event.
      raise TicketObjectNotFoundException if !ticket_object_resource.check_fields_synced? #checking freshdesk__Freshdesk_Ticket_Object__c exist or not.
      sf_ticket_det = ticket_object_resource.find @payload[:data_object].id # get the freshdesk__Freshdesk_Ticket_Object__c using the Ticket id
      co_attributes, co_custom_fields, ticket_id = perform_api_actions "update", sf_ticket_det # Create Contact, Account If needed and also create the payload for create/update of the freshdesk ticket object.
      raise Error if co_attributes.blank?
      if sf_ticket_det.present?
        object_id = sf_ticket_det.first["Id"]
        update_res = ticket_object_resource.update co_attributes, object_id
        update_res = update_custom_fields co_custom_fields, object_id
      else
        create_res = ticket_object_resource.create co_attributes
        update_res = update_custom_fields co_custom_fields, create_res["Id"]
      end
    rescue TicketObjectNotFoundException => e
      deactivate_ticket_sync!
      Rails.logger.debug "freshdesk__Freshdesk_Ticket_Object__c is not found in Salesforce for this account. Error - #{error}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "freshdesk__Freshdesk_Ticket_Object__c is not found in Salesforce for this account. Error - #{error}", :account_id => Account.current.id}})
    rescue => e   
      Rails.logger.debug "Error in Creating/Updating the Salesforce Ticket Object: #{e.message}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error in Creating/Updating the Salesforce Ticket Object: #{e.message}", :account_id => Account.current.id}})
    end

    private

    def perform_api_actions action, sf_ticket_det=nil
      ticket = @payload[:data_object]
      co_attributes ={}
      fd_user = ticket.requester
      # Contact/Account information of the FDTicket will be updated only for the first time. ????
      if action == "create" || sf_ticket_det.blank? #create action if there is no freshdesk__Freshdesk_Ticket_Object__c with id.
        fd_comp_name = if ticket.company.present? 
          ticket.company.name 
        elsif fd_user.companies.present?
          fd_user.company_name
        else
          FD_COMPANY #If No Company present choose FRESHDESK_UNKNOWN_COMPANY.
        end
        co_attributes = assign_contact_det fd_comp_name, fd_user
      end
      ticket_states = ticket.ticket_states
      co_attributes = assign_ticket_prop ticket, fd_user, co_attributes
      TICKET_STATES.each do |sf,fd|
        co_attributes[sf] = ticket_states.safe_send(fd)
      end
      co_custom_fields = populate_custom_fields ticket #separating Post of Custom fields and Normal Fields, Because it will error out it the Custom_field is not exist.
      [co_attributes, co_custom_fields, ticket.id]
    end

    def assign_contact_det fd_comp_name, fd_user
      fd_contact = {}
      user_emails = UserEmail.where(:user_id => fd_user.id)
      fd_emails = [] # for multiple Email support.
      fd_emails = user_emails.map{|obj| "#{obj.email}"}
      email_query = fd_emails.map{|email| "Email='#{email}'"}
      fd_det = ["email", "mobile", "phone", "twitter_id", "fb_profile_id", "external_id"]
      user_det = Hash[CONTACT_FIELDS.zip fd_det]
      user_det.each do |k, v|
        fd_contact[k] = fd_user.safe_send(v) if fd_user.safe_send(v).present? && v != "email"
      end 
      other_query =  fd_contact.map{|k,v| "#{k}='#{v}'"}
      query = email_query.concat(other_query).join(' OR ') # Query will be the same.
      sf_account_id, sf_con_id, acc_name_for_sync, con_name_for_sync = perform_contact_action query, fd_comp_name, fd_user, fd_contact, fd_emails
      co_attributes = {}
      co_attributes["freshdesk__SalesforceAccount__c"] = sf_account_id
      co_attributes["freshdesk__SalesforceContact__c"] = sf_con_id
      co_attributes["freshdesk__RequesterName__c"] = con_name_for_sync.truncate(40)
      co_attributes # needed for setting the Contact, Account ID for the Ticket Object to be Created or Updated.
    end

    def perform_contact_action query, fd_comp_name, fd_user, fd_contact, fd_emails
      #we will be connecting the freshdesk__Freshdesk_Ticket_Object__c to the Freshdesk ticket's Contact and it's Company.(We Don't care if the Salesforce Contact is associated to a different company)
      sf_contactid = fd_user.custom_field['cf_sfcontactid']
      contact_response = (sf_contactid.present?) ? (contact_resource.find_by_id sf_contactid): (contact_resource.find query)
      contact_response = contact_resource.find query if contact_response == 404
      acc_name_for_sync = fd_comp_name
      if contact_response.present?
        sf_con_det = (sf_contactid.present? && (contact_response.class.eql? Hash)) ? contact_response : (contact_weightage_check contact_response, fd_contact, fd_emails)
        con_name_for_sync = sf_con_det["Name"]
        sf_con_id = sf_con_det["Id"]
        sf_account_id, acc_name_for_sync = sync_account sf_con_det, fd_comp_name
      else
        sf_account_id = get_or_create_sf_account fd_comp_name
        con_name_for_sync = fd_user.name
        fd_contact.merge!(contact_name_split con_name_for_sync)
        fd_contact["AccountId"] = sf_account_id
        sf_con_det = create_sf_contact fd_contact, fd_user
        sf_con_id = sf_con_det["Id"]
      end
      [sf_account_id, sf_con_id, acc_name_for_sync, con_name_for_sync] #values will be used while creating the freshdesk__Freshdesk_Ticket_Object__c object.
    end

    def contact_name_split full_name
      split_names = full_name.split(" ")
      (split_names.size > 1) ? {"LastName" => split_names.last, "FirstName" => split_names[0..-2].join(" ")} : {"LastName" => full_name}
    end

    def contact_weightage_check records, fd_contact, fd_emails
      #modified to make Multiple Email Support.
      match = 0
      if records.size > 1
        contact_weights = [32, 16, 8, 4, 2, 1]
        weights = Hash[CONTACT_FIELDS.zip contact_weights]
        weight_rec= Array.new(records.size, 0)
        records.each_with_index do |rec, i|
          fd_contact.keys.each do |key|
            weight_rec[i] += weights[key] if rec[key] == fd_contact[key]
          end
          weight_rec[i] += 32 if fd_emails.include?(rec["Email"])
        end
        match = weight_rec.index(weight_rec.max)
      end
      records[match]
    end

    def sync_account sf_con_det, fd_comp_name
      #fd_comp_name will be FRESHDESK_UNKNOWN_COMPANY if no Company for FD exist.
      # create or return the specific account. We cannot get a Contacts account name in a single query using CE API's so we will be finding using its Id.
      if sf_con_det["AccountId"].present? 
        sf_account_id  = sf_con_det["AccountId"]
        account_response = account_resource.find sf_account_id
        acc_name_for_sync = account_response["Name"]
        # different account name and company is not FD_UNKNOWN create, 
        unless (fd_comp_name.downcase).eql? (acc_name_for_sync.downcase) 
          unless fd_comp_name.eql? FD_COMPANY
            sf_account_id = get_or_create_sf_account fd_comp_name
            acc_name_for_sync = fd_comp_name
          end 
        end
      else
        sf_account_id = get_or_create_sf_account fd_comp_name
        acc_name_for_sync = fd_comp_name
      end
      [sf_account_id, acc_name_for_sync]
    end

    def create_sf_contact fd_contact, fd_user
      body = (fd_user.helpdesk_agent) ? fd_contact : fd_contact.merge(get_contact_create_body fd_user)
      sf_con_det = contact_resource.create body
      sf_con_det
    end

    def get_or_create_sf_account fd_comp_name 
      # Get the account if no account is present then create a new one.
      account_response =  account_resource.find URI.encode("?where=Name='#{fd_comp_name}'")
      if account_response.present?
        sf_account_det = account_response.first
        acc_id = sf_account_det["Id"]
      else
        if fd_comp_name.eql? FD_COMPANY
          body = { "Name" => fd_comp_name}
        else
          body = get_account_create_body fd_comp_name
        end
         #including all the values that the user selected from the Account Sync fields.
        sf_account_det = account_resource.create body
        acc_id = sf_account_det["Id"]
      end
      acc_id
    end

    private

    def deactivate_ticket_sync!
      # remove the va rules if freshdesk__Freshdesk_Ticket_Object__c is not exist.
      remove_sync_option
      @installed_app.va_rules.each do |x| 
        x.active = false
        x.save
      end
      @installed_app.save!
    end

    def remove_sync_option
      @installed_app.configs[:inputs]["ticket_sync_option"] = "0"
    end

    def get_account_create_body fd_comp_name
      company = Company.where(:name => fd_comp_name).first
      account_sync_hash = Hash[@installed_app.configs_companies["fd_fields"].zip(@installed_app.configs_companies["sf_fields"])]
      build_body company, account_sync_hash
    end

    def get_contact_create_body fd_user
      contact_sync_hash = Hash[@installed_app.configs_contacts["fd_fields"].zip(@installed_app.configs_contacts["sf_fields"])]
      contact_sync_hash.delete("name")
      build_body fd_user, contact_sync_hash
    end

    def build_body object, sync_hash # object is either either contact or company.
      body = {}
      sync_hash.each do |k,v|
        value = object.safe_send(k)
        body[v] = value if value.present?
      end
      body
    end

    def assign_ticket_prop ticket, fd_user, co_attributes
      co_attributes["freshdesk__RequesterEmail__c"] = fd_user.safe_send("email")
      co_attributes["freshdesk__TicketPriority__c"] = TicketConstants::PRIORITY_NAMES_BY_KEY[ticket.priority].titlecase
      co_attributes['freshdesk__TicketSource__c'] = Helpdesk::Source.default_ticket_source_token_by_key[ticket.source].to_s.titlecase
      co_attributes["freshdesk__TicketProduct__c"] = (ticket.product.present?) ? ticket.product.name : nil
      co_attributes["freshdesk__TicketGroup__c"] = (ticket.group.present?) ? ticket.group.name : nil
      co_attributes["freshdesk__TicketTags__c"] = ticket.ticket_tags
      co_attributes["freshdesk__TicketDescription__c"] = ticket.description.truncate(32767)
      co_attributes["freshdesk__TicketStatus__c"]  = ticket.status_name
      co_attributes["freshdesk__AgentEmail__c"] = (ticket.responder.present?)? ticket.responder.email : nil
      co_attributes["freshdesk__AgentName__c"] = (ticket.responder.present?)? ticket.responder.name.truncate(40) : nil
      if ticket.responder.present?
        user_response  = contact_resource.find_user "Email='#{ticket.responder.email}'"
        co_attributes["freshdesk__SalesforceUser__c"] = user_response.first["Id"] unless user_response.blank?
      end       
      TICKET_FIELDS.each do |sf,fd|
        co_attributes[sf] = ticket.safe_send(fd)
      end
      co_attributes
    end

    def populate_custom_fields ticket
      # generate all the ticket Custom fields in a JSON format with keys (name__s) = Ticket state values.
      co_custom_fields = {}
      fd_custom_fields = Account.current.ticket_fields.custom_fields
      fd_custom_fields = fd_custom_fields.reject{|x| (x.section_field?) }
      formatted_fields = sf_custom_fields(fd_custom_fields)
      return co_custom_fields if fd_custom_fields.blank?
      formatted_fields.each do |custom_field|
        fd_cust_field_value = ticket.safe_send(custom_field[0])
        co_custom_fields[custom_field[1]] = fd_cust_field_value
      end
      co_custom_fields
    end

    def update_custom_fields co_custom_fields, object_id  #will error out if the Freshdesk Ticket Custom fields is not exactly present in the Salesforce Ticket Object as well.
      ticket_object_resource.update co_custom_fields, object_id if co_custom_fields.present?
    end

    def sf_custom_fields(fd_custom_fields)
      fd_custom_fields.map do |custom_field|
       [ custom_field.name , "#{custom_field.name.gsub(/_[0-9]+$/,'')}__c" ]
      end
    end
  end
end

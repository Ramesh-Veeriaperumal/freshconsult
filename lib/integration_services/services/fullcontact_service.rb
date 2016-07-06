module IntegrationServices::Services
  class FullcontactService < IntegrationServices::Service

    def api_url
      "https://api.fullcontact.com/v2/"
    end

    def receive_install    
      app_rule = @installed_app.account.va_rules.build(
        :rule_type => VAConfig::INSTALLED_APP_BUSINESS_RULE,
        :name => "fullcontact_sync",
        :description => "This rule will fetch data from full contact.",
        :match_type => "any",
        :filter_data =>[
            {
              :name => "any",
              :operator => "is",
              :value => "any",
              :action_performed=>{
                :entity=>"User",
                :action=>:create
              }
            },
            {
              :name => "any",
              :operator => "is",
              :value => "any",
              :action_performed=>{
                :entity=>"Company",
                :action=>:create
              }
            },
            {
              :name => "any",
              :operator => "is",
              :value => "any",
              :action_performed=>{
                :entity=>"Company",
                :action=>:update
              }
            }
          ],
        :action_data => [
          { 
            :name => "Integrations::IntegrationRulesHandler",
            :value => "execute",
            :service => "fullcontact",
            :event => "trigger_webhook",
            :include_va_rule => true
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

    def receive_trigger_webhook
      @payload[:webhook_flag] = true
      if @payload[:act_on_object].is_a?(User)
        response = contact_resource.fetch_contact
      elsif @payload[:act_on_object].is_a?(Company)
        response = company_resource.fetch_company
      else
        return
      end
    end

    def receive_webhook_response
      if @payload[:model_name].eql? "contact"
        contact_resource.update_contact
      elsif @payload[:model_name].eql? "company"
        company_resource.update_company
      else
        Rails.logger.debug "Exception in Fullcontact Integration -- Webhook response without model_name parameter"
        NewRelic::Agent.notice_error("Exception in Fullcontact Integration -- Webhook response without model_name parameter")
        return
      end
    end

    def receive_contact_diff
      begin
        @payload[:webhook_flag] = false
        @payload[:act_on_object] = current_contact
        result = contact_resource.fetch_contact
        if result[:status].eql? 200
          payload[:result] = result[:message]
          diff = contact_resource.get_contact_diff
          result = {:status => 200, :message => "Fetch successful", :fd_fields => diff }
        else
          result = {:status => 400, :message => result[:message]}
        end
      rescue Exception => e
        Rails.logger.debug "Exception in Fullcontact Integration :: #{e.to_s} :: #{e.backtrace.join("\n")}"
        result = {:status => 500, :message => I18n.t(:'integrations.fullcontact.message.backend_issue')}
      end
      result
    end

    def receive_company_diff
      begin
        @payload[:webhook_flag] = false
        @payload[:act_on_object] = current_company
        result = company_resource.fetch_company
        if result[:status].eql? 200
          payload[:result] = result[:message]
          diff = company_resource.get_company_diff
          #fd_fields => { fd_field_name => [fd_existing_value, fc_new_value] }
          result = {:status => 200, :message => "Fetch successful", :fd_fields => diff }
        else
          result = {:status => 400, :message => result[:message]}
        end
      rescue Exception => e
        Rails.logger.debug "Exception in Fullcontact Integration :: #{e.to_s} :: #{e.backtrace.join("\n")}"
        result = {:status => 500, :message => I18n.t(:'integrations.fullcontact.message.backend_issue')}
      end
      result
    end

    def receive_update_db
      begin
        if @payload[:type] == "contact"
          @payload[:contact_id] = @payload[:id]
          response = contact_resource.update_fields
        elsif @payload[:type] == "company"
          @payload[:company_id] = @payload[:id]
          response = company_resource.update_fields
        end
      rescue Exception => e
        Rails.logger.debug "Exception in Fullcontact Integration :: #{e.to_s} :: #{e.backtrace.join("\n")}"
        response = {:status => 404, :message => I18n.t(:'integrations.fullcontact.message.update_failure')}
      end
      response
    end

  private

    def contact_resource
      @contact_resource ||= IntegrationServices::Services::Fullcontact::ContactResource.new(self)
    end

    def company_resource
      @company_resource ||= IntegrationServices::Services::Fullcontact::CompanyResource.new(self)
    end

    def current_contact
      @current_contact ||= Account.current.contacts.find(@payload[:contact_id])
    end

    def current_company
      @current_company ||= Account.current.companies.find(@payload[:company_id])
    end

  end
end

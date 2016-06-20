module IntegrationServices::Services
  class FreshsalesService < IntegrationServices::Service

    def instance_url
      self.configs['domain']
    end 

    def receive_contact_fields
      contact_resource.get_fields
    end

    def receive_account_fields
      account_resource.get_fields
    end

    def receive_lead_fields
      lead_resource.get_fields
    end

    def receive_deal_fields
      deal_resource.get_fields
    end

    def receive_deal_stage_choices
      deal_resource.stage_dropdown_values
    end

    def receive_fetch_user_selected_fields
      send("#{@payload[:type]}_resource").get_selected_fields(@installed_app.send("configs_#{@payload[:type]}_fields"), @payload[:value])
    end

    def account_resource
      @account_resource ||= IntegrationServices::Services::Freshsales::FreshsalesAccountResource.new(self)
    end

    def contact_resource
      @contact_resource ||= IntegrationServices::Services::Freshsales::FreshsalesContactResource.new(self)
    end

    def lead_resource
      @lead_resource ||= IntegrationServices::Services::Freshsales::FreshsalesLeadResource.new(self)
    end

    def deal_resource
      @deal_resource ||= IntegrationServices::Services::Freshsales::FreshsalesDealResource.new(self)
    end

    def receive_create_deal
      begin
        integrated_local_resource = receive_integrated_resource
        return { :error => "Link failed.This ticket is already linked to a deal", :remote_id => integrated_local_resource["remote_integratable_id"] } unless integrated_local_resource.blank?
        @payload.delete(:ticket_id)
        deal_resource.create @payload
      rescue RemoteError => e
        return error(e.to_s, { :exception => e.status_code })
      end
    end

    def receive_link_deal
      begin
        integrated_local_resource = receive_integrated_resource
        return { :error => "Link failed.This ticket is already linked to a deal", :remote_id => integrated_local_resource["remote_integratable_id"] } unless integrated_local_resource.blank?
        @installed_app.integrated_resources.create(
          :remote_integratable_id => @payload[:remote_id],
          :remote_integratable_type => "deal",
          :local_integratable_id => @payload[:ticket_id],
          :local_integratable_type => "Helpdesk::Ticket",
          :account_id => @installed_app.account_id
        )
      rescue Exception => e
        return error("Error in linking the ticket with the freshsales deal", { :exception => e })
      end
    end

    def receive_unlink_deal
      begin
        integrated_resource = @installed_app.integrated_resources.where(
          :local_integratable_id => @payload[:ticket_id],
          :remote_integratable_id => @payload[:remote_id], 
          :remote_integratable_type => "deal"
        ).first
        return { :error => "The deal is already unlinked from the ticket", :remote_id => "" } if integrated_resource.blank?
        integrated_resource.destroy
      rescue Exception => e
        return error("Error in unlinking the ticket with the freshsales deal", { :exception => e })
      end
    end

    def error(msg, error_params = {})
      exception = error_params[:exception]
      web_meta[:status] = error_params[:status] || :not_found
      if exception.present?
        NewRelic::Agent.notice_error(exception,{:custom_params => {:description => "Problem in freshsales service : #{exception.message}"}})
      end
      return { :message => msg }
    end

    def flush_integrated_resources integrated_resource
      deal = deal_resource.find integrated_resource["remote_integratable_id"]
      if deal["errors"].present? && deal["errors"]["code"] == 404
        @payload[:remote_id] = integrated_resource["remote_integratable_id"]
        receive_unlink_deal
        return {}
      end
      integrated_resource
    end

    def receive_integrated_resource
      return {} if @payload[:ticket_id].blank?
      integrated_resource = super
      if integrated_resource.present?
        integrated_resource = flush_integrated_resources integrated_resource
      end
      integrated_resource
    end
  end
end
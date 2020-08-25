# frozen_string_literal: true

module IntegrationServices::Services
  class FreshworkscrmService < IntegrationServices::Service
    include InstalledApplicationConstants

    INSTALL_DEFAULT_FIELD_HASH = { 'contact_fields': 'display_name', 'account_fields': 'name',
                                   'contact_labels': 'Full name', 'account_labels': 'Name', 'deal_view': '0' }.freeze

    def instance_url
      self.configs['domain']
    end

    def receive_contact_fields
      contact_resource.get_fields
    end

    def receive_account_fields
      account_resource.get_fields
    end

    def self.construct_default_integration_params(params)
      INSTALL_DEFAULT_FIELD_HASH.merge!('domain': INSTALLATION_DOMAIN % { domain_url: params['domain'] }, 'auth_token': params['auth_token'], 'ghostvalue': params['ghostvalue'])
    end

    def receive_deal_fields
      deal_resource.get_fields
    end

    def receive_deal_stage_choices
      deal_resource.stage_dropdown_values
    end

    def receive_fetch_form_fields
      common_resource.fetch_form_fields
    end

    def account_resource
      @account_resource ||= IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.new(self)
    end

    def contact_resource
      @contact_resource ||= IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.new(self)
    end

    def deal_resource
      @deal_resource ||= IntegrationServices::Services::Freshworkscrm::FreshworkscrmDealResource.new(self)
    end

    def common_resource
      @common_resource ||= IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource.new(self)
    end

    def receive_create_contact
      contact_resource.create(@payload, @web_meta)
    end

    def receive_fetch_dropdown_choices
      common_resource.fetch_dropdown_choices(@payload)
    end

    def receive_fetch_autocomplete_results
      common_resource.fetch_autocomplete_results(@payload)
    end

    def receive_create_deal
      integrated_local_resource = receive_integrated_resource
      return { error: 'Link failed.This ticket is already linked to a deal', remote_id: integrated_local_resource['remote_integratable_id'] } if integrated_local_resource.present?

      @payload.delete(:ticket_id)
      deal_resource.create @payload
    rescue RemoteError => e
      error(e.to_s, exception: e.status_code)
    end

    def receive_link_deal
      integrated_local_resource = receive_integrated_resource
      return { error: 'Link failed.This ticket is already linked to a deal', remote_id: integrated_local_resource['remote_integratable_id'] } if integrated_local_resource.present?

      @installed_app.integrated_resources.create(
        remote_integratable_id: @payload[:remote_id],
        remote_integratable_type: 'deal',
        local_integratable_id: @payload[:ticket_id],
        local_integratable_type: 'Helpdesk::Ticket',
        account_id: @installed_app.account_id
      )
    rescue StandardError => e
      error('Error in linking the ticket with the Freshworkscrm deal', exception: e)
    end

    def receive_unlink_deal
      integrated_resource = @installed_app.integrated_resources.where(
        local_integratable_id: @payload[:ticket_id],
        remote_integratable_id: @payload[:remote_id],
        remote_integratable_type: 'deal'
      ).first
      return { error: 'The deal is already unlinked from the ticket', remote_id: '' } if integrated_resource.blank?

      integrated_resource.destroy
    rescue StandardError => e
      error('Error in unlinking the ticket with the Freshworkscrm deal', exception: e)
    end

    def error(msg, error_params = {})
      exception = error_params[:exception]
      web_meta[:status] = error_params[:status] || :not_found
      NewRelic::Agent.notice_error(exception, custom_params: { description: "Problem in Freshworkscrm service : #{exception.message}" }) if exception.present?
      { message: msg }
    end

    def flush_integrated_resources(integrated_resource)
      deal = deal_resource.find integrated_resource['remote_integratable_id']
      if deal['errors'].present? && deal['errors']['code'] == 404
        @payload[:remote_id] = integrated_resource['remote_integratable_id']
        receive_unlink_deal
        return {}
      end
      integrated_resource
    end

    def receive_integrated_resource
      return {} if @payload[:ticket_id].blank?

      integrated_resource = super
      integrated_resource = flush_integrated_resources(integrated_resource) if integrated_resource.present?
      integrated_resource
    end
  end
end

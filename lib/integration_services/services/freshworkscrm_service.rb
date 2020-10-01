# frozen_string_literal: false

module IntegrationServices::Services
  class FreshworkscrmService < IntegrationServices::Service
    include InstalledApplicationConstants

    INSTALL_DEFAULT_FIELD_HASH = { 'contact_fields' => 'display_name', 'account_fields' => 'name',
                                   'contact_labels' => 'Full name', 'account_labels' => 'Name', 'deal_view' => '0' }

    def instance_url
      self.configs['domain']
    end

    def receive_contact_fields
      contact_resource.fetch_fields('contacts', 'display_name' => 'Full name')
    end

    def receive_account_fields
      account_resource.fetch_fields('sales_accounts')
    end

    def self.construct_default_integration_params(params)
      INSTALL_DEFAULT_FIELD_HASH.merge!('domain' => format(INSTALLATION_DOMAIN, domain_url: params['domain']), 'auth_token' => params['auth_token'], 'ghostvalue' => params['ghostvalue'])
    end

    def receive_deal_fields
      deal_resource.fetch_fields('deals')
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
  end
end

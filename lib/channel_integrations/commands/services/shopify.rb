module ChannelIntegrations::Commands::Services
  class Shopify
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants
    include ChannelIntegrations::CommonActions::Ticket
    include Helpdesk::TagMethods

    def receive_create_ticket(payload)
      build_tags(payload)
      build_custom_fields(payload)
      build_placeholders(payload)
      payload[:data][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]
      ticket = create_ticket(payload)
      ::Rails.logger.info("Ticket created for abandoned cart :: Account ID : #{payload['account_id']}")
      ticket
    rescue StandardError => e
      ::Rails.logger.error("Error creating abnadoned cart ticket :: #{e.message}")
    end

    def build_tags(payload)
      tags = sanitize_tags(payload[:data][:tags])
      payload[:data][:tags] = construct_tags(tags) if tags
    end

    def build_custom_fields(payload)
      if payload[:data][:custom_fields].blank?
        payload[:data].delete(:custom_fields)
        return
      end

      ticket_fields = Account.current.ticket_fields_from_cache
      name_mapping = TicketsValidationHelper.name_mapping(ticket_fields).each_with_object({}) do |(key, value), hash|
        hash[key.to_sym] = value.to_sym
      end
      ParamsHelper.modify_custom_fields(payload[:data][:custom_fields], name_mapping.invert)
      checkbox_names = TicketsValidationHelper.custom_checkbox_names(ticket_fields)
      ParamsHelper.assign_checkbox_value(payload[:data][:custom_fields], checkbox_names)
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, payload[:data])
    end

    def build_placeholders(payload)
      contact = current_account.contacts.find_by_email(payload[:data][:email])
      contact_hash = contact.present? ? contact.as_json["user"].stringify_keys : {}
      company_hash = contact.present? && contact.company.present? ? contact.company.as_json["company"].stringify_keys : {}
      shopify = payload.delete(:shopify).with_indifferent_access
      payload[:data][:description] = Liquid::Template.parse(payload[:data][:description]).render({ 'shopify': shopify, 'contact': contact_hash, 'company': company_hash }.stringify_keys)
    end
  end
end

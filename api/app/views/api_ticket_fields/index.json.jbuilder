json.array! @items do |ticket_field|
  json.cache! CacheLib.compound_key(ticket_field, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! ticket_field, :id, :default, :description, :label, :name, :position, :required_for_closure
    json.set! :portal_cc, ticket_field.portal_cc if ticket_field.default_requester?
    json.set! :portal_cc_to, ticket_field.portalcc_to if ticket_field.default_requester?

    json.set! :type, ticket_field.field_type
    json.set! :required_for_agents, ticket_field.required
    json.set! :required_for_customers, ticket_field.required_in_portal
    json.set! :label_for_customers, ticket_field.label_in_portal
    json.set! :customers_can_edit, ticket_field.editable_in_portal
    json.set! :displayed_to_customers, ticket_field.visible_in_portal

    json.partial! 'shared/utc_date_format', item: ticket_field
  end

  json.set! :choices, ticket_field.ticket_field_choices if ticket_field.ticket_field_choices.present?

  if ticket_field.field_type == 'nested_field'
    json.set! :nested_ticket_fields do
      json.array! ticket_field.nested_ticket_fields do |tf_nested_field|
        json.cache! CacheLib.key(tf_nested_field, params) do
          json.extract! tf_nested_field, :description, :id, :label, :label_in_portal, :level, :name, :ticket_field_id

          json.partial! 'shared/utc_date_format', item: tf_nested_field
        end
      end
    end
  end
end

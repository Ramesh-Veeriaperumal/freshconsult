json.array! @items do |tf|
  json.cache! [controller_name, action_name, tf] do
    json.(tf, :id, :default, :description, :label, :name, :position, :required_for_closure)
    json.set! :portal_cc, tf.portal_cc if tf.default_requester_field
    json.set! :portal_cc_to, tf.portalcc_to if tf.default_requester_field

    json.set! :type, tf.field_type
    json.set! :required_for_agents, tf.required
    json.set! :required_for_customers, tf.required_in_portal
    json.set! :label_for_customers, tf.label_in_portal
    json.set! :customers_can_edit, tf.editable_in_portal
    json.set! :displayed_to_customers, tf.visible_in_portal

    json.partial! 'shared/utc_date_format', item: tf
  end

  choices = tf.get_ticket_field_choices
  json.set! :choices, choices if choices.present?

  if tf.field_type == 'nested_field'
    json.set! :nested_ticket_fields do
      json.array! tf.nested_ticket_fields do |tf_nested_field|
        json.cache! [controller_name, action_name, tf_nested_field] do
          json.(tf_nested_field, :description, :id, :label, :label_in_portal, :level, :name, :ticket_field_id)

          json.partial! 'shared/utc_date_format', item: tf_nested_field
        end
      end
    end
  end
end

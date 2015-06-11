json.array! @api_ticket_fields do |tf|
  json.(tf, :id, :default, :description, :editable_in_portal, :label, :label_in_portal, :name, :position, :required, :required_for_closure, :required_in_portal, :visible_in_portal)
  json.set! :portal_cc, tf.field_options.try(:[], 'portalcc') if tf.field_type == 'default_requester'
  json.set! :portal_cc_to, tf.field_options.try(:[], 'portalcc_to') if tf.field_type == 'default_requester'

  json.set! :type, tf.field_type

  json.partial! 'shared/utc_date_format', item: tf

  json.set! :choices, tf.api_choices(@account)

  if tf.field_type == 'nested_field'
    json.set! :nested_choices, tf.api_nested_choices

    json.set! :nested_ticket_fields do
      json.array! tf.nested_ticket_fields do |tf_nested_field|
        json.(tf_nested_field, :description, :id, :label, :label_in_portal, :level, :name, :ticket_field_id)

        json.partial! 'shared/utc_date_format', item: tf_nested_field
      end
    end
  end
end

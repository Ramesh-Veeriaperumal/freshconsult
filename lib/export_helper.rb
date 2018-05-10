module ExportHelper

  DEFAULT_CONTACT_EXPORT_FIELDS = %w(name phone mobile).freeze
  DEFAULT_COMPANY_EXPORT_FIELDS = %w(name).freeze
  MAX_QUERY_LIMIT = 480 #FQL has a query limit of 512. We are adding display_id condition to the query we get to the API. So setting the API query limit at 480
  
  def validate_export_params(cname_params)
    cname_params.merge(ticket_fields: (merge_custom_fields(cname_params, :ticket_fields) || {}).keys,
                           contact_fields: (merge_custom_fields(cname_params, :contact_fields) || {}).keys,
                           company_fields: (merge_custom_fields(cname_params, :company_fields) || {}).keys)
  end

  def sanitize_custom_fields(cname_params)
    fields = [:ticket_fields, :contact_fields, :company_fields]
    fields.each do |field|
      cname_params[field] = merge_custom_fields(cname_params, field, true)
    end  	
  end

  def merge_custom_fields(cname_params, field_type, prefix = nil)
    if cname_params[field_type]
      request_params = cname_params[field_type].except(:custom_fields)
      return request_params.merge(custom_field_name(cname_params, field_type)) if prefix
      request_params.merge(cname_params[field_type][:custom_fields] || {})
    end
  end

  def custom_field_name(cname_params, field_type)
    fields = []
    if cname_params[field_type][:custom_fields]

      cname_params[field_type][:custom_fields].each do |key, value|
        fields << if field_type == :ticket_fields
                    { "#{key}_#{Account.current.id}" => value }
                  else
                    { "cf_#{key}" => value }
                  end
      end
    end
    fields.inject(:merge) || {}
  end

  def ticket_fields_list
    flexi_fields = Account.current.ticket_fields_from_cache.select { |x| x.default == false }.map(&:name).collect { |x| display_name(x, :ticket) }
    # Use EXP_TICKET_FIELDS once shared ownership fields added to ticket_scheduled_export
    default_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
    default_fields += ['product_name'] if Account.current.multi_product_enabled? # Changed to feature check as ember validation won't have product presence check
    default_fields + flexi_fields + ['description']
  end

  def contact_fields_list
    # Check privilege
    fields = if customer_export_privilege?
               default_contact_fields + custom_contact_fields
             else
               DEFAULT_CONTACT_EXPORT_FIELDS.map(&:clone)
             end
    fields << Helpdesk::TicketModelExtension.customer_fields('contact').map { |x| x[:value] }
    fields.flatten
  end

  def company_fields_list
    # Check privilege
    fields = if customer_export_privilege?
               default_company_fields + custom_company_fields
             else
               DEFAULT_COMPANY_EXPORT_FIELDS
             end
    fields.flatten
  end

end
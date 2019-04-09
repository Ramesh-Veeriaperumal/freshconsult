module CustomFieldsHelper
  include RepresentationHelper
  def custom_field_hash(model)
    safe_send("custom_#{model}_fields").inject([]) do |arr, field|
      begin
        field_value = safe_send(field.name)
        custom_field = {
          name:  field.name,
          column:  field.column_name,
          label: field.label,
          type:  field.field_type.to_s,
          value: field.field_type == :custom_date ? utc_format(field_value) : field_value
        }
        if field.field_type == :custom_dropdown
          custom_field[:choice_id] = fetch_choice_id(field, field_value) if field_value
        end
        arr.push(custom_field)
      rescue Exception => e
        Rails.logger.error "Error while fetching #{model}
        custom field value - #{e}\n#{e.message}\n#{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def custom_company_fields
    account.company_form.company_fields_from_cache.reject { |field| field.column_name == 'default' }
  end

  def custom_contact_fields
    account.contact_form.contact_fields_from_cache.reject { |field| field.column_name == 'default' }
  end

  def fetch_choice_id(field, field_value)
    field.choices.select { |x| x[:value] == field_value }.last[:id]
  end
end

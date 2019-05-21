module CustomFieldsHelper
  include RepresentationHelper
  def custom_field_hash(model)
    arr = []
    safe_send("custom_#{model}_fields").each do |field|
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
          if field_value
            choice_id = fetch_choice_id(field, field_value)
            custom_field[:value] = nil if choice_id.blank?
          end
          custom_field[:choice_id] = choice_id
        end
        arr.push(custom_field)
      rescue Exception => e
        Rails.logger.error("Error while fetching custom-field #{field.name} of #{model} - account #{account.id} - #{e.message} :: #{e.backtrace[0..10].inspect}")
        NewRelic::Agent.notice_error(e)
      end
    end
    arr
  end

  def custom_company_fields
    account.company_form.company_fields_from_cache.reject { |field| field.column_name == 'default' }
  end

  def custom_contact_fields
    account.contact_form.contact_fields_from_cache.reject { |field| field.column_name == 'default' }
  end

  def fetch_choice_id(field, field_value)
    field.choices.select { |x| x[:value] == field_value }.last.try(:[], :id)
  end
end

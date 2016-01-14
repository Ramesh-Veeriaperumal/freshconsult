module Integrations::Dynamicscrm::CrmUtil

  # Front end javascript is designed to work on the returned json array formed here.
  def admin_config_filter api_data_arr, inputs_hash
    data_arr = []
    api_data_arr.each do |data_ele|
      hash_data = {}
      unless data_ele[:entities].blank?
        if data_ele[:entities].first.attributes
          hash_data.reverse_merge!(admin_configured_label_fields(data_ele, inputs_hash))
          hash_data.reverse_merge!(mandatory_label_fields(data_ele))
        end
      end
      data_arr.push(hash_data) unless hash_data.blank?
    end
    data_arr.to_json
  end

  private
    #Mandatory fields that are used in the Frontend Javascript.
    def mandatory_label_fields data
      hash_data = {}
      hash_data["internal_use_entity_type"] = data["EntityName"]
      hash_data["Full Name"] = data[:entities].first.attributes.fullname
      hash_data["Contact ID"] = data[:entities].first.id
      unless data[:entities].first.attributes.parentcustomerid.blank?
        hash_data["Account ID"] = data[:entities].first.attributes.parentcustomerid['Id']
        hash_data["Account Name"] = data[:entities].first.attributes.parentcustomerid['Name']
      else
        hash_data["Account ID"] = data[:entities].first.attributes.accountid
        hash_data["Account Name"] = data[:entities].first.attributes.name
      end
      hash_data
    end

    def admin_configured_label_fields data, inputs_hash
      hash_data = {}
      entity_type = data["EntityName"]
      label_key = "#{entity_type}_labels"
      field_key = "#{entity_type}s"
      labels = inputs_hash[label_key].split(",")
      fields = inputs_hash[field_key]
      labels.zip(fields).each do |label, field|
        begin
          hash_data[label] = eval("data[:entities].first."+field)
        rescue
          hash_data[label] = nil
          Rails.logger.debug("Dynamics cannot evaluate #{field} \n#{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
      hash_data
    end

end
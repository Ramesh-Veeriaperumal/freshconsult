#Wrappers for the gem https://github.com/TinderBox/dynamics_crm
module Integrations::Dynamicscrm::ApiUtil
  include Integrations::Constants

  # Return an hash with authentication status and client object
  def dynamics_client client_params, contact_email=nil
    result_hash = {}
    begin
      organization_name = client_params["organization_name"]
      host_name = host_name_from_end_point(client_params["end_point"])
      
      login_url = (client_params["instance_type"] == CRM_INSTANCE_TYPES["on_demand"]) ? 
                                            DYNAMICS_CRM_CONSTANTS['rst2_login_url'] : client_params["login_url"]
                                            
      client = DynamicsCRM::Client.new({organization_name: organization_name, hostname: host_name,
                                            login_url: login_url})
      client.authenticate(client_params["domain_user_email"], client_params["decrypted_password"])
      client.retrieve_multiple("contact", [["emailaddress1", "Equal", contact_email]]) unless contact_email.blank?
      result_hash["client_obj"] = client
      result_hash["status"] = SUCCESS
    rescue => e
      Rails.logger.debug("Error while authenticating dynamics CRM  \n#{e.message}\n#{e.backtrace.join("\n")}")
      result_hash["status"] = FAILURE
    end
    result_hash
  end

  def dynamics_module_data client, module_type, user_email, gem_raw_data=false
    data = client.retrieve_multiple(module_type, [["emailaddress1", "Equal", user_email]])
    return data if gem_raw_data
    hash_data = {}
    unless data[:entities].blank?
      if data[:entities].first.attributes
        hash_data = label_field_map(module_type, data)
        hash_data.reverse_merge!(custom_label_field_map(data[:entities].first.attributes, data[:entities].first))
      end
    end
    hash_data
  end

  private
    # Can add more basic fields that have a complex object expansion from the gem here.
    def label_field_map module_type, attributes_arr
      hash_data = {}
      unless module_type == "account"
        hash_data["Job Title"] = "attributes.jobtitle"
        hash_data["Mobile Phone"] = "attributes.mobilephone"
      end
      hash_data["Telephone"] = "attributes.telephone1"
      hash_data["Address"] = "attributes.address1_composite"
      hash_data["Owner"] = "attributes.ownerid['Name']"
      hash_data
    end

    def custom_label_field_map attributes_arr, entity_data=nil
      hash_data = {}
      attributes_arr.each do |k, v|
        if k.include? "new_" #custom field data starts with "new_"
          hash_data["#{k}"] = (formatted_custom_field?(entity_data, k) == true) ? 
                                                            "formatted_values.#{k}" : "attributes.#{k}"
        end
      end
      hash_data
    end

    def formatted_custom_field? entity_data, key
      begin
        eval("entity_data.formatted_values.#{key}").blank? ? false : true
      rescue
        false
      end
    end

    def host_name_from_end_point end_point
      temp = end_point.split("//")
      result = nil
      if temp.kind_of?(Array)
        unless temp.second.blank?
          temp = temp.second.split("/")
          result = temp.first || nil if temp.kind_of?(Array)
        end
      end
      result
    end

end
module Integrations::CloudElements::Crm::CrmResourceUtil
  include Integrations::CloudElements::Crm::Constant

  def salesforce_v2_selected_fields(fields, response, success_codes, type)
    if success_codes.include? response.status
      response_hash = Hash.new
      address_fields = ["MailingStreet","MailingCity","MailingState","MailingCountry","MailingPostalCode"]
      fields_array = format_selected_fields fields, address_fields
      field_response = parse(response.body)
      response_hash = {FRONTEND_OBJECTS[:totalSize] => field_response.length, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => []}
      field_response.each do |response|
        hash = { FRONTEND_OBJECTS[:attributes]=> {FRONTEND_OBJECTS[:type] => type}}
        fields_array.each do |field|
          hash[field] = response[field]
        end
        hash["accountId"] = response["AccountId"] if type == "Contact" && response["AccountId"]
        hash["Id"] = response["Id"]
        hash.delete("AccountName")
        response_hash[FRONTEND_OBJECTS[:records]].push(hash)
      end
    end
    response_hash
  end

  def dynamics_v2_selected_fields(fields, response, success_codes, type)
    if success_codes.include? response.status
      response_hash = Hash.new
      fields_array = fields.split(",")
      field_response = parse(response.body)
      response_hash = {FRONTEND_OBJECTS[:totalSize] => field_response.length, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => []}
      field_response.each do |response|
        hash = { FRONTEND_OBJECTS[:attributes]=> {FRONTEND_OBJECTS[:type] => type}}
        fields_array.each do |field|
          hash[field] = response[FRONTEND_OBJECTS[:attributes]][field.split(".").second]
        end
        hash["Id"] = response["id"]
        hash["accountId"] = response[FRONTEND_OBJECTS[:attributes]]["parentcustomerid"] if type == "Contact" && response["attributes"]["parentcustomerid"].present?
        hash.delete("AccountName")
        response_hash[FRONTEND_OBJECTS[:records]].push(hash)
      end
    end
    response_hash
  end

  def process_ids record,app_name
    if app_name.eql? "salesforce_v2"
    elsif app_name.eql? "dynamics_v2"
      record["Id"] = record["id"]
      record.delete("id")
    end    
    record
  end

  def format_selected_fields fields,address_fields = []
    return [] unless  fields.present?
    fields_array = fields.split(",")
    fields_array.push("Id")
    if fields_array.include?("Address")
      fields_array.map! { |x| x == "Address" ? address_fields : x }
      fields_array.flatten!
    end
    fields_array
  end
end
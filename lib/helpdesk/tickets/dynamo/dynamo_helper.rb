module Helpdesk::Tickets::Dynamo::DynamoHelper
  include Helpdesk::Tickets::Dynamo::ExceptionHandler

  #Provide hash/range | { :key => <attribute_name>, :value => <attribute_value> }
  #attribute_value | <Hash,Array,String,Numeric,Boolean,IO,Set,nil>
  #projection_attribute | Comma seperated list of attribute names
  #consistent_read | boolean
  def self.get_item(table, hash, range = nil, projection_attributes = nil, consistent_read = true)
    dynamo_sandbox(table) do
      params = base_params(table, hash, range)
      params.merge!({:projection_expression => projection_attributes}) if projection_attributes
      params.merge!({:consistent_read => consistent_read})

      response = $dynamo_v2_client.get_item(params)
    end
  end

  #put_item ==> Hash of attr_name => attr_value pairs
  #             not including the hash and range key
  #condition_expression ==> string containing condition expression in dynamo format
  def self.put_item(table, hash, range, put_item, condition_expression = nil)
    dynamo_sandbox(table) do
      params = { table_name: table }
      
      #item
      item = {hash[:key] => hash[:value]}
      item.merge!({range[:key] => range[:value]}) if range
      item.merge!(put_item) if put_item.present?
      params.merge!(item: item)

      #options
      params.merge!({condition_expression: condition_expression}) if condition_expression.present?
      params.merge!({
        return_values: "ALL_OLD",
        return_consumed_capacity: "INDEXES", # accepts INDEXES, TOTAL, NONE
        return_item_collection_metrics: "SIZE" # accepts SIZE, NONE
      }) if Rails.env.eql?("development")

      response = $dynamo_v2_client.put_item(params)
    end
  end

  

  def self.batch_write

  end

  def self.update_item

  end

  #Use this only for adding items to attributes of type set
  #condition_expression ==> string containing condition expression in dynamo format
  #val_to_add ==> Hash of {attr_name => array of values to add}
  #condition_expression ==> string containing condition expression in dynamo format
  #action can be ADD or DELETE
  def self.update_set_attributes(table, hash, range, val_to_add, action = "ADD", condition_expression = nil)
    dynamo_sandbox(table) do
      params = base_params(table, hash, range)

      update_exp = ""
      exp_attr_val = {}
      count = 1

      if val_to_add.present?
        val_to_add.each do |attrb, value|
          update_exp += "#{action} #{attrb} :val#{count} "
          exp_attr_val[":val#{count}"] = value.to_set
          count = count + 1      
        end
        params.merge!(update_expression: update_exp)
        params.merge!(expression_attribute_values: exp_attr_val)
      end

      params.merge!({condition_expression: condition_expression}) if condition_expression.present?
      params.merge!({
        return_values: "UPDATED_NEW",
        return_consumed_capacity: "INDEXES", # accepts INDEXES, TOTAL, NONE
        return_item_collection_metrics: "SIZE" # accepts SIZE, NONE
      }) if Rails.env.eql?("development")

      response = $dynamo_v2_client.update_item(params)
    end
  end

  #Provide hash/range = { :key => <attribute_name>, :value => <attribute_value> }
  #attribute_value <Hash,Array,String,Numeric,Boolean,IO,Set,nil>
  def base_params(table, hash, range = nil)
    key =  { hash[:key] => hash[:value] }
    key.merge!({range[:key] => range[:value]}) if range
    {
      table_name: table, # required
      key: key 
    }
  end
end
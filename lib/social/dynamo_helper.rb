module Social::DynamoHelper

  extend Social::Util
  include Social::Constants
  include Social::Dynamo::ExceptionHandler


  #Create a DynamoDB table with the given params. Waits in a loop till the table is
  #created before exiting
  def self.create_table(name, hash, range, read_capacity, write_capacity)
    dynamo_sandbox(name) do
      return if table_exists?(name)

      table_options = {
        :table_name => name,
        :attribute_definitions => [hash],
        :key_schema => [
          {
            :attribute_name => hash[:attribute_name],
            :key_type       => "HASH"
          }
        ],
        :provisioned_throughput => {
          :read_capacity_units  =>  read_capacity,
          :write_capacity_units => write_capacity
        }
      }

      if !range.nil?
        table_options[:attribute_definitions].push(range)
        table_options[:key_schema].push({
          :attribute_name => range[:attribute_name],
          :key_type => "RANGE"
        })
      end

      table = $social_dynamoDb.create_table(table_options)

      #Checking status of the table
      wait_for_table_resource(name, "CREATING")
    end
  end
  
  def self.increase_rw_table(name, start_read, final_read, write)
    current_read = start_read
 
    while current_read < final_read
      current_read = current_read * 2
      if current_read > final_read
        current_read = final_read
      end
      update_rw_table(name, current_read, write)
    end
    
  end


  def self.update_rw_table(name, read, write)
    dynamo_sandbox(name) do
      table_options = {
        :table_name => name,
        :provisioned_throughput => {
          :read_capacity_units  => read,
          :write_capacity_units => write
        }
      }

      $social_dynamoDb.update_table(table_options)
      wait_for_table_resource(name, "UPDATING")
    end
  end

  #Delete a DynamoDb table. Wait in a loop till the table is deleted
  def self.delete_table(name)
    dynamo_sandbox(name) do 
      return unless table_exists?(name)
      $social_dynamoDb.delete_table(:table_name => name)
      wait_for_table_resource(name, "DELETING")
    end
  end


  # Added the default_argument expected=true for the race condition.
  # Race happens when reply to a tweet from portal is inserted into dynamo and the same tweet
  # comes as a part of the gnip stream(cos of the rule value from:screenname).
  # For inserting into feeds table , "false" is passed - feed wil be inserted only once and wont be updated
  # For inserting replies made from portal and interactions table insert, it takes the default argument "true"
  def self.insert(table, item, schema, expected=true)
    dynamo_sandbox(table, item) do
      hash_key = schema[:hash][:attribute_name]
      range_key = schema[:range][:attribute_name]

      options = {
        :table_name => table,
        :item => item,
        :expected => {
          hash_key => {
            :exists => false
          },
          range_key => {
            :exists => false
          }
        }
      }
      $social_dynamoDb.put_item(options)
    end
  rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => exception
    update(table, item, schema) if expected
  end


  def self.update(table, item, schema, put_items=[], delete_items= [])
    dynamo_sandbox(table, item) do
      #Update the item
      hash_key  = schema[:hash][:attribute_name]
      range_key = schema[:range][:attribute_name]


      item_copy = item.dup
      item.each do |key, value|
        item_copy.delete(key) if value.keys.first == :s
      end

      options = {
        :table_name => table,
        :key => {
          hash_key  => item[hash_key],
          range_key => item[range_key]
        },
        :attribute_updates => {},
        :return_values => "ALL_NEW"
      }

      item_copy.each do |key, value|
        action = case 
          when put_items.include?(key) then DYNAMO_ACTIONS[:put]
          when delete_items.include?(key) then DYNAMO_ACTIONS[:delete]
          else DYNAMO_ACTIONS[:add]
        end
        update_hash = {
          :action => action
        }
        update_hash.merge!(:value => value) unless action == DYNAMO_ACTIONS[:delete]
        options[:attribute_updates][key] = update_hash
      end
      
      $social_dynamoDb.update_item(options)
    end
  end
  
  def self.delete_item(table, item, schema)
    dynamo_sandbox(table, item) do
      hash_key  = schema[:hash][:attribute_name]
      range_key = schema[:range][:attribute_name]
      
      hash_attribute  = schema[:hash][:attribute_type].to_sym
      range_attribute = schema[:range][:attribute_type].to_sym
      
      options = {
          :table_name => table,
          :key => {
            hash_key => {
              hash_attribute => "#{item[:hash_key]}"
            },
            range_key => {
              range_attribute => "#{item[:range_key]}"
            }
          }
        }
      $social_dynamoDb.delete_item(options)
    end
  end
  
  # Eventually consistent read
  def self.query(table, hash, range, schema, limit, sort_type)
    dynamo_sandbox(table) do
      response_arr = []
      hash_key = schema[:hash][:attribute_name]

      query_options = {
        :table_name         => table,
        :select             => "ALL_ATTRIBUTES",
        :scan_index_forward => sort_type,
        :key_conditions => {
          hash_key => hash
        }
      }

      query_options.merge!({:limit => limit}) if limit.present?
      
      if !range.nil?
        range_key = schema[:range][:attribute_name]
        query_options[:key_conditions][range_key] = range
      end
      
      
      while true
        response = $social_dynamoDb.query(query_options)
        response_arr << response[:member] 
        break unless response[:last_evaluated_key]
        query_options = query_options.merge({ :exclusive_start_key => response[:last_evaluated_key]})
      end
      response_arr.flatten
    end
  end

  # Strongly consistent read
  def self.get_item(table, hash, range, schema, attributes_to_get, consistent_read = true)
    dynamo_sandbox(table) do
      hash_key = schema[:hash][:attribute_name]
      range_key = schema[:range][:attribute_name]
      
      hash_attribute  = schema[:hash][:attribute_type].to_sym
      range_attribute = schema[:range][:attribute_type].to_sym
      
      query_options = {
        :table_name => table,
        :key => {
            hash_key => {
              hash_attribute => "#{hash}"
            },
            range_key => {
              range_attribute => "#{range}"
            }
        },
        :consistent_read    => consistent_read
      }
      query_options.merge!(:attributes_to_get => attributes_to_get) if attributes_to_get
      response = $social_dynamoDb.get_item(query_options)
    end
  end

  # Eventually consistent read
  def self.batch_get(*tables_info)
    dynamo_sandbox("BATCH GET") do
      requested_items = {}
      response_arr = []
      tables_info.each do |table_info|
        requested_items.merge!({
          table_info[:name] => {
            :keys => table_info[:keys]
          }
        })
      end
      while true
        response = $social_dynamoDb.batch_get_item(:request_items => requested_items)
        response_arr << response
        break if response[:unprocessed_keys].blank?
        requested_items = response[:unprocessed_keys]
      end
      response_arr
    end
  end


  def self.select_table(table, time)
    properties        = DYNAMO_DB_CONFIG[table]
    valid_date_format = select_valid_date(time, table)
    "#{TABLES[table][:name]}_#{properties["suffix"]}_#{valid_date_format}"
  end


  def self.table_validity(dynamo_table, selected_table, time)
    table_name = select_table(dynamo_table, time)
    if (selected_table <=> table_name) != -1
      return true
    else
      return false
    end
  end


  def self.table_exists?(name)
    dynamo_sandbox(name) do
      table_data = $social_dynamoDb.describe_table(:table_name => name)
    end
  end

  private
  def self.wait_for_table_resource(name, status)
    #Checking status of the table
    dynamo_sandbox(name) do
      table_data = $social_dynamoDb.describe_table(:table_name => name)
      while table_data[:table][:table_status] == status
        sleep 1
        table_data = $social_dynamoDb.describe_table(:table_name => name)
      end
    end
  end

end

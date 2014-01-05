module Social::DynamoHelper

  include Social::Constants

  #@ARV@ TODO Have a common sandbox to raise errors

  #Create a DynamoDB table with the given params. Waits in a loop till the table is
  #created before exiting
  def self.create_table(name, hash, range, read_capacity, write_capacity)
    return if table_exists?(name)

    table_options = {
      :table_name => name,
      :attribute_definitions => [hash],
      :key_schema => [
        {
          :attribute_name => hash[:attribute_name],
          :key_type =>       "HASH"
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
    table_data = $social_dynamoDb.describe_table(:table_name => name)
    while table_data[:table][:table_status] == "CREATING"
      sleep 1
      table_data = $social_dynamoDb.describe_table(:table_name => name)
    end
  end


  #Delete a DynamoDb table. Wait in a loop till the table is deleted
  def self.delete_table(name)
    return unless table_exists?(name)

    begin
      $social_dynamoDb.delete_table(:table_name => name)

      table_data = $social_dynamoDb.describe_table(:table_name => name)
      while table_data[:table][:table_status] == "DELETING"
        sleep 1
        table_data = $social_dynamoDb.describe_table(:table_name => name)
      end
    rescue AWS::DynamoDB::Errors::ResourceNotFoundException => e
      return true
    rescue => e
      return false
    end
  end


  def self.insert(table, item, schema)
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

    begin
      $social_dynamoDb.put_item(options)
    rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => e
      #An entry with the same primary key already exists, so update the entry instead of over-writing it
      update(table, item, schema)
    end
  end


  def self.update(table, item, schema)
    #Update the item
    hash_key = schema[:hash][:attribute_name]
    range_key = schema[:range][:attribute_name]


    item_copy = item.dup
    item.each do |key, value|
      item_copy.delete(key) if value.keys.first == :s
    end

    options = {
      :table_name => table,
      :key => {
        hash_key => item[hash_key],
        range_key => item[range_key]
      },
      :attribute_updates => {},
      :return_values => "UPDATED_NEW"
    }

    item_copy.each do |key, value|
      update_hash = {
        :value => value,
        :action => "ADD"
      }
      options[:attribute_updates][key] = update_hash
    end

    $social_dynamoDb.update_item(options)
  end


  def self.query(table, hash, range, schema, limit)
    hash_key = schema[:hash][:attribute_name]

    query_options = {
      :table_name => table,
      :select => "ALL_ATTRIBUTES",
      :limit => limit,
      :consistent_read => true,
      :key_conditions => {
        hash_key => hash
      }
    }

    if !range.nil?
      range_key = schema[:range][:attribute_name]
      query_options[:key_conditions][range_key] = range
    end

    #puts query_options.inspect
    response = $social_dynamoDb.query(query_options)
  end


  def self.select_table(table, time)
    properties = DYNAMO_DB_CONFIG[table]
    retention = TABLES[table][:retention_period]
    reference_date = Time.parse(TABLES[table][:db_reference_date])

    days = ((time - reference_date)/retention).to_i #Number of days since reference date
    date = reference_date + retention*days #Valid Date
    extension = name_format(date)

    table_name ="#{TABLES[table][:name]}_#{properties["suffix"]}_#{extension}"
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
    begin
      table_data = $social_dynamoDb.describe_table(:table_name => name)
      return true
    rescue AWS::DynamoDB::Errors::ResourceNotFoundException => e
      return false
    end
  end

  private
    def self.name_format(time)
      return time.strftime("%Y%m%d")
    end

end

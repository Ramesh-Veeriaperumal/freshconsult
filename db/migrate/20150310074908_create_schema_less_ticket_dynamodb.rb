class CreateSchemaLessTicketDynamodb < ActiveRecord::Migration
	shard :none
  
  def up
  	
  	table_name = if Rails.env.production?
  		"fd_schema_less_ticket_dynamo_#{Rails.env[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
  	else
  		"fd_schema_less_ticket_dynamo_#{Rails.env[0..3]}"
  	end

    table_options = {
			:table_name => table_name,
			:attribute_definitions => [
				{:attribute_name => "account_id", :attribute_type => "N"},
				{:attribute_name => "ticket_id", :attribute_type => "N"}
			],
			:key_schema => [
				{:attribute_name => "account_id", :key_type => "HASH"},
				{:attribute_name => "ticket_id", :key_type => "RANGE"}
			],
			:provisioned_throughput => {
        :read_capacity_units  =>  1,
        :write_capacity_units => (Rails.env.production? ? 20 : 5)
      }
		}

	  table = $dynamo.create_table(table_options)
  end

  def down
    
  end
end

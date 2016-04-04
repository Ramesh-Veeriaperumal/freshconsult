namespace :email_dynamo do

	desc "Create dynamoDB tables for the next month - Runs every month 28th"
	task :create_dynamo_db_tables => :environment do
	  if Rails.env.production?
			puts "Creating SchemaLessTicketDynamo Table"

			table_options = {
				:table_name => "fd_schema_less_ticket_dynamo_#{Rails.env[0..3]}_#{(Time.now + 1.months).utc.strftime('%Y_%m')}",
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
	        :write_capacity_units => 50
	      }
		  }

	    table = $dynamo.create_table(table_options)
    end
	end
	
end
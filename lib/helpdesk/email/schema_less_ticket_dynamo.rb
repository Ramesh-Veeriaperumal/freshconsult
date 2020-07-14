module Helpdesk
	module Email
    class SchemaLessTicketDynamo < ::Dynamo

      hash_key(:account_id, :n)
    	range(:ticket_id, :n)

      @@rails_env = Rails.env[0..3]

    	def self.table_name
    		if Rails.env.production?
		      "fd_schema_less_ticket_dynamo_#{@@rails_env}_#{Time.now.utc.strftime('%Y_%m')}"
		    else
		    	"fd_schema_less_ticket_dynamo_#{@@rails_env}"
		    end
	    end

    end
  end
end
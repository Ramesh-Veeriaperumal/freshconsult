module Helpdesk
	module Email
    class ArchiveDatastore < ::Dynamo

      hash_key(:account_id, :n)
      range(:unique_index, :s)

    	def self.table_name
    		"email_archive_data_#{Rails.env}"
	    end

    end
  end
end

module Helpdesk
	module DBStore
		class MailDBStoreFactory

			include Helpdesk::Email::Constants
			#move to appropriate place

			def self.getDBStoreObject(type, dbStorage = DB_STORAGE[:s3])
				#Initial version - Should optimise
				case type
				when DBTYPE[:primary]
					return Helpdesk::DBStore::S3PrimaryDBStore.new(S3_CONFIG[:primary_email_storage_bucket]) if dbStorage == DB_STORAGE[:s3]
				when DBTYPE[:archive]
					return Helpdesk::DBStore::S3ArchiveDBStore.new(S3_CONFIG[:archive_email_storage_bucket]) if dbStorage == DB_STORAGE[:s3]
				when DBTYPE[:failed]
					return Helpdesk::DBStore::S3FailedDBStore.new(S3_CONFIG[:failed_email_storage_bucket]) if dbStorage == DB_STORAGE[:s3]	
				end
				
				return NotImplementedError,"Type not supported !!"
			end

		end
	end
end
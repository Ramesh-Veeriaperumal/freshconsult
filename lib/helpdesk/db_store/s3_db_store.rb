module Helpdesk
	module DBStore
		module S3DBStore

			def self.included(base)
    			base.extend(ClassMethods)
  			end

			def get_s3_metadata_hash(options={})
				s3_metadata_hash = {
					metadata: {
					},
					server_side_encryption: "AES256"
				}
				s3_metadata_hash[:metadata].merge!(options)
				return s3_metadata_hash
			end

			def fetch(key_path)
				self.class.fetch(bucket_name, key_path) #throws exception if no key found
			end

			def delete(key_path)
				self.class.delete(bucket_name, key_path)
			end

			def delete_batch(key_paths)
				self.class.batch_delete(bucket_name, key_paths)
			end

			def list_object_metadata(prefix)
				self.class.list_object_metadata(bucket_name, prefix)
			end
  			
  			module ClassMethods

				def fetch(bucket, key_path)
					s3_response_obj = AwsWrapper::S3.read_with_metadata(bucket, key_path)
					fetch_response = {
						:eml => s3_response_obj.body,
						:metadata => s3_response_obj.metadata
					}
					return fetch_response
				rescue Aws::S3::Errors::NoSuchKey => e
					raise Helpdesk::Email::Errors::EmailDBRecordNotFound, "The specified key is not found in s3 : #{e.message} - #{e.backtrace}"
				rescue => e
					raise Helpdesk::Email::Errors::EmailDBFetchError, "Error while fetching from S3 : #{e.message} - #{e.backtrace}"
				end

				def delete(bucket, key_path)
					AwsWrapper::S3.delete(bucket, key_path)
				rescue => e
					raise Helpdesk::Email::Errors::EmailDBDeleteError, "Error while deleting from S3 : #{e.message} - #{e.backtrace}"
				end

				def delete_batch(bucket, key_paths)
					AwsWrapper::S3.batch_delete(bucket,key_paths)
				rescue => e
					raise Helpdesk::Email::Errors::EmailDBDeleteError, "Error during batch_delete from S3 : #{e.message} - #{e.backtrace}"
				end

				def list_object_metadata(bucket, prefix)
				    object_list = AwsWrapper::S3.list(bucket, prefix, true)
				    object_list_with_metadata = []
				    object_list.each do |object|
				    	head_object = AwsWrapper::S3.read_only_metadata(bucket, object.key)
				    	head_obj_hash = {
				    		:key => object.key,
				    		:metadata => head_object.metadata
				    	}
				    	object_list_with_metadata << head_obj_hash
				    end
				    return object_list_with_metadata
				rescue => e
					raise Helpdesk::Email::Errors::EmailDBError, "Error while listing all objects from S3 : #{e.message} - #{e.backtrace}"
				end
			end
		end
	end
end
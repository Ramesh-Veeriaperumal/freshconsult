# This file uses aws-sdk version 2 for s3 calls 
# (which is being used by reports currently)
module AwsWrapper
  class S3
    DELETE_OBJECT_LIMIT = 500 # PRE-RAILS: MAX 1000 keys
    
    def self.upload(bucket_name, key, file_path, options = {})
      fetch_obj(bucket_name, key).upload_file(file_path, options)
    end
    
    def self.put(bucket_name, key, content, options = {})
      fetch_obj(bucket_name, key).put({ body: content }.merge(options))
    end
    
    def self.copy(copy_source, target_bucket, target_key)
      fetch_obj(target_bucket, target_key).copy_from(copy_source: copy_source)
    end

    # Return IO
    def self.read_io(bucket_name, key, options = {})
      $s3_client.get_object({ bucket: bucket_name, key: key }.merge(options)).body # PRE-RAILS: used in reports export
    end

    def self.read(bucket_name, key, options = {})
      read_io(bucket_name, key, options).read
    end

    def self.fetch_obj(bucket_name, key)
      Aws::S3::Resource.new(client: $s3_client).bucket(bucket_name).object(key)
    end

    def self.read_only_metadata(bucket_name, key)
      $s3_client.head_object(bucket: bucket_name, key: key)
    end

    def self.read_with_metadata(bucket_name, key)
      $s3_client.get_object(bucket: bucket_name, key: key)
    end

    def self.write_with_metadata(bucket_name, key, content, options = {})
      data = {
        body: content,
      }
      data.merge!(options)
      fetch_obj(bucket_name, key).put(data)
    end

    def self.move_object(source_bucket, source_key, target_bucket, target_key, options = {})
      fetch_obj(source_bucket, source_key).move_to({bucket: target_bucket, key: target_key} , options)
    end
    
    # `fetch_all` - Boolean - Specifies whether to get all the objects in the bucket or
    #                         only 1000 (By default it lists the 1000 objects in the bucket)
    # Making fetch_all to true will trigger an expensive call. 
    # TODO: add timeout in while(true)
    # DONT FETCH ALL THE OBJECTS(i.e. `fetch_all` = true) UNLESS ITS ABSOLUTELY NECESSARY
    def self.list(bucket_name, prefix_key, fetch_all)
      response_arr = []
      request_params = { bucket: bucket_name, prefix: prefix_key }
      while true
        response = $s3_client.list_objects(request_params)
        response_arr << response.contents.to_a
        break unless fetch_all && response.is_truncated
        request_params = request_params.merge(marker: response.contents.last.key)
      end
      response_arr.flatten.compact
    end

    # `keys` - Array of object keys ["sample/object1.csv", "sample/object2.csv"]
    def self.batch_delete(bucket_name, keys)
      key_hash = keys.map {|k| { key: k} }
      # Only 1000 keys can be deleted in a single API call
      key_hash.each_slice(1000) do |sliced_keys|
        $s3_client.delete_objects({
          bucket: bucket_name,
          delete: {
            objects: sliced_keys
          }
        })
      end
    end

    def self.delete(bucket_name, key)
      $s3_client.delete_object(
        bucket: bucket_name,
        key: key
      )
    end

    def self.find_with_prefix(bucket, prefix)
      Aws::S3::Bucket.new(bucket).objects(prefix: prefix)
    end

    def self.batch_delete_all(bucket, prefix)
      find_with_prefix(bucket, prefix).batch_delete!
    end

    def self.presigned_url(bucket, key, options = {})
      fetch_obj(bucket, key).presigned_url(:get, options).to_s if key.present? # PRE-RAILS: Need to check options
    end

    def self.public_url(bucket, key, options = {})
      fetch_obj(bucket, key).public_url(options).to_s if key.present? # PRE-RAILS: Need to check options
    end

    def self.exists?(bucket, key)
      fetch_obj(bucket, key).exists?
    end
  end
end
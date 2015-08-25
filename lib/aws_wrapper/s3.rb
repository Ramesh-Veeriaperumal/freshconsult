# This file uses aws-sdk version 2 for s3 calls 
# (which is being used by reports currently)
module AwsWrapper
  class S3
    
    def self.upload(bucket_name, key, file_path, options = {})
      obj = Aws::S3::Resource.new(client: $s3_client).bucket(bucket_name).object(key)
      obj.upload_file(file_path, options)
    end
    
    def self.put(bucket_name, key, content, options = {})
      s3  = Aws::S3::Resource.new(client: $s3_client)
      obj = s3.bucket(bucket_name).object(key)
      obj.put(body: content)
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
    
    def self.fetch(bucket_name, key)
      obj = Aws::S3::Resource.new(client: $s3_client).bucket(bucket_name).object(key)
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
    
    def self.copy(copy_source, target_bucket, target_key)
      s3  = Aws::S3::Resource.new(client: $s3_client)
      obj = s3.bucket(target_bucket).object(target_key)
      obj.copy_from(copy_source: copy_source)
    end
  end
end
module Helpdesk::S3
  module Util

    private
    # s3_partition will genererate a random partion in s3 so that data is evenly spreaded and
    # a four character hex hash partition set in a bucket or sub-bucket namespace could
    # theoretically grow to support millions of operations per second and over a trillion
    # unique keys before we'd need a fifth character in the hash.
    # source http://highscalability.com/blog/2012/3/7/scale-indefinitely-on-s3-with-these-secrets-of-the-s3-master.html
    def s3_partition(key_id)
      # algorithm to calculate should be decided for now i am using reverse of the key
      # this generates a 4 character hex
      # need to identify the place to store
      key_id.to_s.reverse
    end

    # here key is the full path after bucket_name
    # value is json string
    def create(key, value, bucket_name)
      AWS::S3::Bucket.new(bucket_name).objects[key].write(value,:content_type => 'application/json',:server_side_encryption => :aes256)
    end

    # gets key and bucket_name as params
    # returns a json hash
    def read(key, bucket_name)
      json_data = AWS::S3::Bucket.new(bucket_name).objects[key].read(:content_type => 'application/json')
      JSON.parse(json_data)
    end

    # gets key and bucket_name as input
    # deletes the file from s3
    def delete(key, bucket_name)
      AWS::S3::Bucket.new(bucket_name).objects[key].delete
    end

    def exists?(key, bucket_name)
      AWS::S3::Bucket.new(bucket_name).objects[key].exists?
    end

    # genereates the key based on the partition
    def generate_key(account_id,key_id)
      s3_partition(key_id) + "/#{account_id}/#{key_id}"
    end

    public
    # this takes the entries and save the object in s3 as string
    def push_to_s3(args,bucket)
      key = generate_file_path(args[:account_id], args[:key_id])
      if args[:delete]
        delete(key,bucket)
      else
        return if args[:data].blank?
        value = args[:data].to_json
        if args[:create]
          create(key,value,bucket) unless exists?(key, bucket)
        else
          create(key,value,bucket)
        end
      end
    end
  end
end

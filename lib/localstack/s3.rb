module Localstack
  class S3    
    class << self
      def create
        s3_config = YAML::load_file(File.join(Rails.root,"config","s3.yml"))
        buckets   = s3_config[Rails.env].keys - s3_config["common"].keys

        buckets.each do |bucket|
          puts "Creating #{bucket} #{s3_config[Rails.env][bucket]}"
          $s3_client.create_bucket({
            acl: "private", 
            bucket: s3_config[Rails.env][bucket], #{s3_config[Rails.env]['s3_host_name']}
            grant_full_control: "GrantFullControl",
            grant_read: "GrantRead",
            grant_read_acp: "GrantReadACP",
            grant_write: "GrantWrite",
            grant_write_acp: "GrantWriteACP",
          })
        end
      end

      def cleanup
        buckets = $s3_client.list_buckets["buckets"]

        buckets.each do |bucket|
          $s3_client.delete_bucket({
            bucket: bucket.name, 
          })
        end
      end
    end    
  end  
end



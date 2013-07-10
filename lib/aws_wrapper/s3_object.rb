module AwsWrapper
  class S3Object
    
    def self.url_for(content_path,bucket_name,options={})
      bucket = AWS::S3::Bucket.new(bucket_name)
      s3object = AWS::S3::S3Object.new(bucket,content_path)
      s3object.url_for(:read,options).to_s
    end

    def self.store(file_path,file,bucket_name,options={})
      AWS::S3::Bucket.new(bucket_name).objects[file_path].write(file,options)
    end

    def self.find(file,bucket)
      AWS::S3::Bucket.new(bucket).objects[file]
    end

    def self.delete(file,bucket)
      find(file,bucket).delete
    end
  end
end

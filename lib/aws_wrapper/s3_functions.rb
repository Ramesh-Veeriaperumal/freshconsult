module AwsWrapper
  class S3Functions
    class << self
      def perform_operations_in_s3_attachment(s3_path, s3_bucket, temp_file_prefix)
        file = download_from_s3(s3_path, s3_bucket, temp_file_prefix)
        yield(file, s3_path, s3_bucket)
      ensure
        File.delete(file.path) if file
      end

      def fetch_from_s3(s3_path, s3_bucket, temp_file_prefix)
        file = download_from_s3(s3_path, s3_bucket, temp_file_prefix)
        file
      end

      private

        def download_from_s3(s3_path, s3_bucket, temp_file_prefix)
          file = Tempfile.new(temp_file_prefix)
          file.binmode
          file.write(AwsWrapper::S3.read(s3_bucket, s3_path))
          file.flush.seek(0, IO::SEEK_SET) # flush data to file and set RW pointer to beginning
          file
        end
    end
  end
end

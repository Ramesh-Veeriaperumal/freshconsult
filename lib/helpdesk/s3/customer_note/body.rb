# This module is used for saving the customer note body content in s3
require 'helpdesk/s3/util'
module Helpdesk::S3::CustomerNote
  module Body
    # extending the util methods so that they are inherited into this module
    extend Helpdesk::S3::Util

    module ClassMethods
      # generates the entire key path that is stored in s3
      def generate_file_path(account_id, note_id)
        generate_key(account_id, note_id) + "/note_body.json"
      end

      # gets the file from s3 based on account_id and note_id
      def get_from_s3(account_id, note_id, bucket_name)
        read(generate_file_path(account_id, note_id), bucket_name)
      end
    end

    # extended the ClassMethods module so that they are created as classmethods
    extend ClassMethods
  end
end

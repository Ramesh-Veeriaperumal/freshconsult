# This module is used for saving the ticket body content in s3
require "helpdesk/s3/util"
module Helpdesk::S3::Ticket
  module Body
    # extending the util methods so that they are inherited into this module
    extend Helpdesk::S3::Util

    module ClassMethods

      # generates the entire key path that is stored in s3
      def generate_file_path(account_id, ticket_id)
        generate_key(account_id,ticket_id) + "/ticket_body.json"
      end

      # gets the file from s3 based on account_id and ticket_id
      def get_from_s3(account_id,ticket_id)
        read(generate_file_path(account_id,ticket_id),S3_CONFIG[:ticket_body])
      end
    end

    # extended the ClassMethods module so that they are created as classmethods
    extend ClassMethods
  end
end

module Helpdesk
  module Utils
    module Attachment

      def create_attachment_from_params(parent,attachment_params,attachment_info,default_name, options = {})
        created_attachment = parent.attachments.build(attachment_params, options)
        if attachment_info
          attachment_name = utf8_name(attachment_info["filename"],default_name)
          if attachment_name
            created_attachment.content.instance_write(:file_name, attachment_name)
            created_attachment.content_file_name = attachment_name
          end
        end
        created_attachment
      end

      def utf8_name(name, user_readable_name)
        unless name.nil?
          name = sanitize_attachment_name(name)
          name.blank?  ? user_readable_name : name
        end
      end

      private
      def sanitize_attachment_name(name)
        ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
        ic.iconv name
      end
    end
  end
end
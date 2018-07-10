module Helpdesk
  module Utils
    module Attachment
      include EmailServRequest::Validator

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

      def attachment_has_virus?
        is_virus = false
        if !skip_virus_detection && content.queued_for_write && content.queued_for_write[:original] && content.queued_for_write[:original].path
          files = {}
          files[content_file_name] = Faraday::UploadIO.new(content.queued_for_write[:original].path, content.content_type)
          results = is_attachment_has_virus?(files)
          is_virus = results.select { |file| file['Result'] == 'VIRUS_FOUND' }.present?
        end
        return is_virus
      end

      def attachment_virus_detection_enabled?
        Account.current.launched?(:attachment_virus_detection)
      end

      private
      def sanitize_attachment_name(name)
        ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
        ic.iconv name
      end
    end
  end
end
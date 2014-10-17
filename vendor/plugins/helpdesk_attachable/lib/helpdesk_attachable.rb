# HelpdeskAttachable
module HelpdeskAttachable
    include HelpdeskExceptions

    # MAX_ATTACHMENT_SIZE = 1024
    MAX_ATTACHMENT_SIZE = 15.megabyte
    def self.included(base) 
      base.extend ClassMethods
    end

    module ClassMethods
      def has_many_attachments
        has_many :attachments,
          :as => :attachable,
          :class_name => 'Helpdesk::Attachment',
          :dependent => :destroy do
            def build(args)
              proxy_owner.validate_attachment_size(args)
              super args
            end
        end

        include InstanceMethods
      end

      def has_many_cloud_files
        has_many :cloud_files,
          :as => :droppable,
          :class_name => 'Helpdesk::CloudFile',
          :dependent => :destroy 
      end

    end
    
    module InstanceMethods
      def validate_attachment_size(args)
        return unless args
        unless @total_attachment_size
          @total_attachment_size = (attachments || []).collect{ |a| a.content_file_size }.sum 
        end
        @total_attachment_size += args[:content].size
        if @total_attachment_size > MAX_ATTACHMENT_SIZE
          raise HelpdeskExceptions::AttachmentLimitException, "Attachment limit exceeded!.. We allow only 15MB." 
        end
      end
    end
  end
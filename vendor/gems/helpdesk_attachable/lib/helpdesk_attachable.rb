# HelpdeskAttachable
require "helpdesk_exceptions/attachment_limit_exception"
require 'active_support/core_ext/numeric/bytes'
require "limit_exceed_rescue"
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
              proxy_association.owner.validate_attachment_size(args)
              super args
            end
        end

        include InstanceMethods
      end

      def has_many_dropboxes
        has_many :dropboxes,
          :as => :droppable,
          :class_name => 'Helpdesk::Dropbox',
          :dependent => :destroy 
      end

    end
    
    module InstanceMethods
      def validate_attachment_size(args)
        return if args.blank?
        unless @total_attachment_size
          @total_attachment_size = (attachments || []).collect{ |a| a.content_file_size }.sum 
        end
        @total_attachment_size += (args.has_key?(:content) ? args[:content].size : 0  )
        if @total_attachment_size > MAX_ATTACHMENT_SIZE
          raise HelpdeskExceptions::AttachmentLimitException, "Attachment limit exceeded!.. We allow only 15MB." 
        end
      end
    end
  end
  # Include hook code here
ActiveRecord::Base.send :include, HelpdeskAttachable
ActionController::Base.send :include, LimitExceedRescue

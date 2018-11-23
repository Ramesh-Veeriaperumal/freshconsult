# HelpdeskAttachable
require "helpdesk_exceptions/attachment_limit_exception"
require 'active_support/core_ext/numeric/bytes'
require "limit_exceed_rescue"
module HelpdeskAttachable
    include HelpdeskExceptions
    include ActionView::Helpers::NumberHelper

    FACEBOOK_ATTACHMENTS_SIZE   = 25.megabyte

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def has_many_attachments
        has_many :attachments,
          :as => :attachable,
          :class_name => 'Helpdesk::Attachment',
          :dependent => :destroy do
            def build(args, options = {})
              proxy_association.owner.validate_attachment_size(args,options)
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
      def validate_attachment_size(args, options = {})
        return unless args

        unless @total_attachment_size
          @total_attachment_size = (attachments || []).collect{ |a| a.content_file_size }.sum
        end
        allowed_limit = options[:attachment_limit] || Account.current.attachment_limit.megabytes
        allowed_limit_human_size = number_to_human_size(allowed_limit)
        @total_attachment_size += args[:content].size

        if @total_attachment_size > allowed_limit
          raise HelpdeskExceptions::AttachmentLimitException, "Attachment limit exceeded. We allow only #{allowed_limit_human_size}."
        end
      end
    end
  end
  # Include hook code here
ActiveRecord::Base.send :include, HelpdeskAttachable
ActionController::Base.send :include, LimitExceedRescue

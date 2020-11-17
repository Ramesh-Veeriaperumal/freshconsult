module Tickets
  class BulkActionsController < ::TicketsController
    include BulkActionConcern
    include BulkApiJobsHelper
    include TicketConcern
    include HelperConcern
    include AttachmentConcern
    include Redis::RedisKeys

    before_filter :archive_disabled?, :setting_enabled?, only: [:bulk_archive]
    before_filter :disable_notification, only: [:bulk_update], if: :notification_not_required?
    after_filter  :enable_notification, only: [:bulk_update], if: :notification_not_required?

    def bulk_archive
      @validation_klass = 'ArchiveValidation'
      params_hash = params[cname].merge(skip_bulk_validations: true)
      return unless validate_body_params(nil, params_hash) && validate_archive_delegator

      archive_tickets
      head 204
    end

    def bulk_delete
      return render_request_error :missing_param, 400 if params[cname].blank? || params[cname].empty?

      return unless validate_bulk_action_params

      @job_id = request.uuid
      initiate_bulk_job(ApiTicketConstants::BULK_API_JOBS_CLASS, params[cname], @job_id, action_name)
      @job_link = current_account.bulk_job_url(@job_id)
      render('bulk_api_jobs/response', status: 202) if @errors.blank?
    end

    def bulk_update
      return unless validate_bulk_update_params

      cname_params[:ids] = @ticket_ids
      fetch_objects
      validate_items_to_update
      update_tickets_in_background
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def self.wrap_params
      ApiTicketConstants::BULK_WRAP_PARAMS
    end

    private

      def archive_tickets
        Archive::AccountTicketsWorker.perform_async(
          account_id: current_account.id,
          archive_days: cname_params[:archive_days] ||
                          (cname_params[:ids].present? && 0) || # If the user prefers to send ticket_ids, there is no need to expect archive_days
                          current_account.account_additional_settings.archive_days,
          ticket_status: :closed,
          display_ids: cname_params[:ids]
        )
      end

      def validate_archive_delegator
        @delegator_klass = 'ArchiveDelegator'
        if cname_params[:ids].present?
          delegator_params = {
            ids: cname_params[:ids],
            permissible_ids: permissible_ticket_ids(cname_params[:ids])
          }
          return validate_delegator(@item, delegator_params)
        end
        true
      end

      def archive_disabled?
        render_request_error :access_denied, 403 if current_account.disable_archive_enabled?
      end

      def setting_enabled?
        render_request_error(:require_feature, 403, feature: FeatureConstants::ARCHIVE_API.to_s.titleize) unless current_account.archive_tickets_api_enabled?
      end

      def constants_class
        :ApiTicketConstants.to_s.freeze
      end

      def scoper
        current_account.tickets
      end

      def validate_update_params(item, validation_context)
        validation_params = @params_hash[:properties].merge(@params_hash.slice(:statuses, :ticket_fields))
        @ticket_validation = TicketValidation.new(validation_params, item, string_request_params?)
        @ticket_validation.valid?(validation_context)
      end

      def fields_to_validate
        return super unless bulk_update?

        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        [*ApiConstants::BULK_ACTION_FIELDS, *ApiTicketConstants::BULK_REPLY_FIELDS, properties: [*ApiTicketConstants::BULK_UPDATE_FIELDS | ['custom_fields' => custom_fields]]]
      end

      def validate_bulk_update_params
        fetch_ticket_fields_mapping
        @validation_klass = 'TicketBulkUpdateValidation'
        @params_hash = cname_params.merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        return unless validate_body_params(nil, @params_hash) && validate_property_params && validate_reply_params

        true
      end

      def validate_property_params
        sanitize_property_params
        @item = current_account.tickets.new
        if cname_params.present?
          assign_attributes_for_update
          delegator_hash = { ticket_fields: @ticket_fields, custom_fields: @custom_fields }
          return unless validate_delegator(@item, delegator_hash)
        end
        true
      end

      def sanitize_property_params
        sanitize_cloud_files(cname_params[:reply][:cloud_files]) if cname_params[:reply]
        @ticket_ids = cname_params[:ids]
        @reply_hash = cname_params[:reply]
        params[cname] = (cname_params[:properties] || {}).deep_dup
        sanitize_ticket_params
      end

      def validate_reply_params
        return true unless @reply_hash.present?

        @attachment_ids = @reply_hash[:attachment_ids]
        @inline_attachment_ids = @reply_hash[:inline_attachment_ids]
        reply_note = @item.notes.build(@reply_hash.slice(:body, :from_email))
        reply_note.cloud_files.build(@reply_hash[:cloud_files]) if @reply_hash[:cloud_files]
        @dklass_computed = nil
        @delegator_klass = 'ConversationDelegator'
        delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments, inline_attachment_ids: @inline_attachment_ids }
        validate_delegator(reply_note, delegator_hash)
      end

      def fetch_objects(items = scoper, check_permission = true)
        ids = check_permission ? permissible_ticket_ids(cname_params[:ids]) : cname_params[:ids]
        @items = items.preload(preload_options).find_all_by_param(ids)
      end

      def preload_options
        [:schema_less_ticket, :flexifield, :ticket_states, :ticket_body]
      end

      def validate_items_to_update
        @items_failed = []
        @validation_errors = {}
        if @params_hash[:properties].present?
          @items.each do |item|
            unless validate_bulk_update_delegator(item)
              @items_failed << item
              @validation_errors.merge!(item.display_id => @ticket_validation)
            end
          end
        end
      end

      def validate_bulk_update_delegator(item)
        @item = item
        assign_attributes_for_update
        delegator_hash = { ticket_fields: @ticket_fields, custom_fields: @custom_fields, statuses: @params_hash[:statuses], request_params: @params_hash[:properties].keys }
        @ticket_validation = if @item && @item.ticket_type == ::Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
                               FsmTicketBulkUpdateDelegator.new(@item, delegator_hash)
                             else
                               TicketBulkUpdateDelegator.new(@item, delegator_hash)
                             end
        @ticket_validation.valid?
      end

      # code duplicated - update method of API Tickets controller
      def assign_attributes_for_update
        assign_protected
        # Assign attributes required as the ticket delegator needs it.
        @custom_fields ||= cname_params[:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
        @delegator_attributes ||= validatable_delegator_attributes
        @item.assign_attributes(@delegator_attributes)
        # Tags should not be overwritten for tickets in bulk update. Should delete from params so that update_attributes does not capture tags changes
        @tags ||= cname_params.delete(:tags)
        @item.tags += @tags if @tags
        @item.assign_description_html(cname_params[:ticket_body_attributes]) if cname_params[:ticket_body_attributes]
      end

      def assign_protected
        @item.build_schema_less_ticket unless @item.schema_less_ticket
        @item.account = current_account
        @item.cc_email = @cc_emails unless @cc_emails.nil?
        assign_ticket_status
      end

      def update_tickets_in_background
        if @params_hash[:properties].present?
          ::Tickets::BulkTicketActions.perform_async(params_for_background_job(tickets_to_update, @params_hash[:properties]))
        end
        queue_replies(tickets_to_update)
      end

      def params_for_background_job(items, properties_hash)
        tags = properties_hash.delete(:tags)
        args = { 'action' => :update_multiple, 'helpdesk_ticket' => properties_hash }
        args['ids'] = items.map(&:display_id)
        args['disable_notification'] = @skip_close_notification.to_s if @skip_close_notification
        args[:tags] = tags.join(',') unless tags.nil?
        ParamsHelper.assign_and_clean_params(ApiTicketConstants::PARAMS_MAPPINGS, args['helpdesk_ticket'])
        args
      end

      def tickets_to_update
        @tkts_to_update ||= @items - @items_failed
      end

      def notification_not_required?
        @skip_notification ||= cname_params.try(:[], :properties).try(:[], :skip_close_notification)
      end

      def queue_replies(tickets)
        return unless @reply_hash.present? && tickets.present?

        ::Tickets::BulkTicketReply.perform_async(params_for_queue(tickets))
      end

      def params_for_queue(tickets)
        ret_hash = {
          ids: tickets.map(&:display_id),
          helpdesk_note: note_params,
          spam_key: spam_key
        }
        [ret_hash, shared_attachment_params, cloud_attachment_params, from_email_params].inject(&:merge)
      end

      def note_params
        {
          private: false,
          user_id: api_current_user.id,
          source: Account.current.helpdesk_sources.note_source_keys_by_token['email'],
          note_body_attributes: {
            body_html: @reply_hash[:body]
          },
          inline_attachment_ids: @inline_attachment_ids ? @inline_attachment_ids : []
        }.merge(attachment_params)
      end

      def shared_attachments
        @shared_attachments ||= begin
          current_account.attachments.where('id IN (?) AND attachable_type IN (?)', @attachment_ids, AttachmentConstants::CLONEABLE_ATTACHMENT_TYPES)
        end
      end

      def shared_attachment_params
        return {} unless shared_attachments.present?

        { shared_attachments: (shared_attachments || []).map(&:id) }
      end

      def attachment_params
        shared_attachment_ids = (shared_attachments || []).map(&:id)
        return {} unless @attachment_ids && (@attachment_ids - shared_attachment_ids).present?

        { attachments: @attachment_ids - shared_attachment_ids }
      end

      def cloud_attachment_params
        return {} unless @reply_hash[:cloud_files]

        { cloud_files: @reply_hash[:cloud_files] }
      end

      def from_email_params
        return {} unless @reply_hash[:from_email]

        { email_config: { reply_email: @reply_hash[:from_email] } }
      end

      def bulk_update?
        action_name.to_sym == :bulk_update
      end

      def spam_key
        Timeout.timeout(SpamConstants::SPAM_TIMEOUT) do
          key = "#{current_user.account_id}-#{current_user.id}"
          value = Time.now.to_i.to_s
          $spam_watcher.perform_redis_op('setex', key, 24.hours, value)
          return "#{key}:#{value}"
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e, description: 'error occured while adding key in redis')
      end
      wrap_parameters(*wrap_params)
  end
end

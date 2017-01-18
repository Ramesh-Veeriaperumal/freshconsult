module Ember
  module Tickets
    class BulkActionsController < ::TicketsController
      include BulkActionConcern
      include TicketConcern
      include HelperConcern
      include AttachmentConcern
      include Helpdesk::ToggleEmailNotification

      before_filter :disable_notification, if: :notification_not_required?
      after_filter  :enable_notification, if: :notification_not_required?

      def bulk_update
        return unless validate_bulk_update_params
        cname_params[:ids] = @ticket_ids
        fetch_objects
        validate_items_to_update
        execute_bulk_update_action unless update_in_background?
        render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
      end

      def bulk_execute_scenario
        return unless validate_body_params
        sanitize_body_params
        @delegator_klass = 'ScenarioDelegator'
        return unless validate_delegator(@item, scenario_id: cname_params[:scenario_id])
        fetch_objects
        execute_scenario
        render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
      end

      def self.wrap_params
        ApiTicketConstants::BULK_WRAP_PARAMS
      end

      private

        # code duplicated - validate_params method of API Tickets controller
        def process_request_params
          # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
          @ticket_fields = Account.current.ticket_fields_from_cache
          @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
          properties_hash = cname_params[:properties]
          ParamsHelper.modify_custom_fields(properties_hash[:custom_fields], @name_mapping.invert) if properties_hash.is_a?(Hash)
        end

        def validate_update_params(item, validation_context)
          validation_params = @params_hash[:properties].merge(@params_hash.slice(:statuses, :ticket_fields))
          @ticket_validation = TicketValidation.new(validation_params, item, string_request_params?)
          @ticket_validation.valid?(validation_context)
        end

        def validate_bulk_update_delegator(item)
          @item = item
          assign_attributes_for_update
          delegator_hash = { ticket_fields: @ticket_fields, custom_fields: @custom_fields }
          @ticket_validation = TicketBulkUpdateDelegator.new(@item, delegator_hash)
          @ticket_validation.valid?
        end

        def validate_bulk_update_params
          process_request_params
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

        def validate_reply_params
          return true unless @reply_hash.present?
          @attachment_ids = @reply_hash[:attachment_ids]
          reply_note = @item.notes.build(@reply_hash.slice(:body, :from_email))
          reply_note.cloud_files.build(@reply_hash[:cloud_files]) if @reply_hash[:cloud_files]
          @dklass_computed = nil
          @delegator_klass = 'ConversationDelegator'
          delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
          validate_delegator(reply_note, delegator_hash)
        end

        def fields_to_validate
          return super unless bulk_update?
          custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
          [*ApiConstants::BULK_ACTION_FIELDS, *ApiTicketConstants::BULK_REPLY_FIELDS, properties: [*ApiTicketConstants::BULK_UPDATE_FIELDS, ['custom_fields' => custom_fields]]]
        end

        def sanitize_property_params
          @ticket_ids = cname_params[:ids]
          @reply_hash = cname_params[:reply]
          params[cname] = (cname_params[:properties] || {}).deep_dup
          sanitize_ticket_params
        end

        def validate_items_to_update
          @items_failed = []
          @validation_errors = {}
          if @params_hash[:properties].present?
            @items.each do |item|
              unless validate_update_params(item, :update) && validate_bulk_update_delegator(item)
                @items_failed << item
                @validation_errors.merge!(item.display_id => @ticket_validation)
              end
            end
          end
        end

        def assign_protected
          @item.build_schema_less_ticket unless @item.schema_less_ticket
          @item.account = current_account
          @item.cc_email = @cc_emails unless @cc_emails.nil?
          assign_ticket_status
        end

        def shared_attachments
          @shared_attachments ||= begin
            current_account.attachments.where('id IN (?) AND attachable_type IN (?)', @attachment_ids, ['Account', 'Admin::CannedResponses::Response'])
          end
        end

        def execute_scenario
          ::Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: cname_params[:scenario_id])
        end

        def fetch_objects(items = scoper)
          @items = items.find_all_by_param(permissible_ticket_ids(cname_params[:ids]))
        end

        def execute_bulk_update_action
          items = @items - @items_failed
          if @params_hash[:properties].present?
            items.each do |item|
              @item = item
              assign_attributes_for_update
              @items_failed << item unless @item.update_ticket_attributes(cname_params.except(:ids))
            end
          end
          queue_replies(items - @items_failed)
        end

        # code duplicated - update method of API Tickets controller
        def assign_attributes_for_update
          assign_protected
          # Assign attributes required as the ticket delegator needs it.
          @custom_fields = cname_params[:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
          @delegator_attributes ||= validatable_delegator_attributes
          @item.assign_attributes(@delegator_attributes)
          @item.assign_description_html(cname_params[:ticket_body_attributes]) if cname_params[:ticket_body_attributes]
        end

        def update_in_background?
          items = @items - @items_failed
          return false if items.length <= ApiTicketConstants::BACKGROUND_THRESHOLD
          if @params_hash[:properties].present?
            ::Tickets::BulkTicketActions.perform_async(params_for_background_job(items, cname_params.except(:ids)))
          end
          queue_replies(items)
        end

        def params_for_background_job(items, properties_hash)
          tags = properties_hash.delete(:tags)
          args = { 'action' => :update_multiple, 'helpdesk_ticket' => properties_hash }
          args['ids'] = items.map(&:display_id)
          args['disable_notification'] = @skip_close_notification if @skip_close_notification
          args[:tags] = tags.join(',') unless tags.nil?
          args
        end

        def constants_class
          :ApiTicketConstants.to_s.freeze
        end

        def notification_not_required?
          !cname_params.blank? && cname_params[:skip_close_notification].try(:to_s) == 'true'
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
            source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
            note_body_attributes: {
              body_html: @reply_hash[:body]
            }
          }.merge(attachment_params)
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
          begin
            Timeout::timeout(SpamConstants::SPAM_TIMEOUT) do
              key = "#{current_user.account_id}-#{current_user.id}"
              value = Time.now.to_i.to_s
              $spam_watcher.perform_redis_op('setex', key, 24.hours, value)
              return "#{key}:#{value}"
            end
          rescue Exception => e
            NewRelic::Agent.notice_error(e, description: 'error occured while adding key in redis')
          end
        end

        wrap_parameters(*wrap_params)
    end
  end
end

module Widget
  # Inherits the workflow of ticket create from api tickets_controller
  class TicketsController < ::TicketsController
    include WidgetConcern
    include Recaptcha::Verify
    include Helpdesk::Permission::Ticket

    before_filter :ticket_creation_enabled?
    before_filter :validate_params
    before_filter :sanitize_params
    before_filter :build_object
    before_filter :check_ticket_permission, only: :create
    before_filter :check_recaptcha, unless: :predictive_ticket?
    before_filter :validate_attachment_ids, if: :attachment_ids?
    skip_before_filter :check_session_timeout

    protected

      def requires_feature(feature)
        unless Account.current.send("#{feature}_enabled?")
          render_request_error(:require_feature, 403, feature: feature.to_s.titleize)
        end
      end

    private

      def validation_class
        Widget::TicketValidation
      end

      def constants_class
        Widget::TicketConstants
      end

      def render_201_with_location(item_id: @item.id)
        render 'widget/tickets/create', status: 201
      end

      def check_ticket_permission
        if current_user.nil? || (current_user && current_user.customer?)
          render_request_error :invalid_requester, 400 unless can_create_ticket?(params[cname][:email])
        end
      end

      def validate_params
        @attachment_ids = cname_params.delete(:attachment_ids)
        @ticket_fields = ticket_fields_scoper
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
        # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        default_fields = @ticket_fields.select(&:default).map { |tf| (ApiTicketConstants::FIELD_MAPPINGS[tf.name.to_sym] || tf.name.to_sym).to_s }
        field = default_fields | "#{constants_class}::#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        set_default_values
        params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        ticket = validation_class.new(params_hash, @item, string_request_params?, additional_params)
        render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
      end

      def ticket_fields_scoper
        fetch_portal
        ticket_fields_scoper = @current_portal.customer_editable_ticket_fields
        # additionally fetching sublevel nested fields because only parent level is saved with editable_in_portal in db
        ticket_fields_scoper << ticket_fields_scoper.map { |tf| Account.current.ticket_fields_from_cache.select { |tfc| tfc if tfc.parent_id == tf.id } if tf.field_type == 'nested_field' }.compact
        ticket_fields_scoper.flatten
      end

      def attachment_ids?
        @attachment_ids.present?
      end

      def validate_attachment_ids
        @delegator_klass = 'WidgetAttachmentDelegator'
        validate_delegator(@item,
                           attachment_ids: @attachment_ids,
                           widget_id: @widget_id,
                           widget_client_id: @client_id)
      end

      def remove_ignore_params
        @meta = params[cname][:meta]
        @predictive = params[cname][:predictive]
        params[cname].except!(*constants_class::PARAMS_TO_REMOVE)
        super
      end

      def additional_params
        additional_params = {}
        additional_params[:is_ticket_fields_form] = @help_widget.ticket_fields_form?
        additional_params[:is_predictive] = predictive_ticket?
        additional_params
      end

      def set_default_values
        super
        params[cname][:product_id] = @help_widget.product_id unless params[cname].key?(:product_id)
        params[cname][:source] = Helpdesk::Source::FEEDBACK_WIDGET
      end

      def check_recaptcha
        verified = @help_widget.captcha_enabled? ? verify_recaptcha : true
        render_request_error(:access_restricted, 403) unless verified
      end

      def assign_protected
        super
        @item.meta_data ||= {}
        constants_class::META_KEY_MAP.keys.each do |meta_key|
          @item.meta_data[meta_key] = (@meta && @meta[meta_key]) || request.env[constants_class::META_KEY_MAP[meta_key]]
        end
        if @meta.try(:[], :seen_articles).present?
          # seen_articles value is set as the stringyfy format similar to portal's seen_articles format
          valid_article_ids = current_account.solution_article_meta.published.where(id: @meta[:seen_articles]).pluck(:id)
          @item.meta_data[:seen_articles] = ActiveSupport::JSON.encode valid_article_ids.map(&:to_s).to_json if valid_article_ids.present?
        end
        add_attachments
      end

      def predictive_ticket?
        @predictive && @help_widget.predictive?
      end

      def ticket_creation_enabled?
        render_request_error(:ticket_creation_not_allowed, 400, id: @widget_id) unless @help_widget.ticket_creation_enabled?
      end

      def sanitize_params
        super

        if current_user.present? &&
           current_user.email != cname_params[:email] &&
           !current_user.emails.include?(cname_params[:email])
          params[cname][:email] = current_user.email
        end
      end

      def build_ticket_body_attributes
        if params[cname][:description]
          ticket_body_hash = { ticket_body_attributes: { description: params[cname][:description] } }
          params[cname].merge!(ticket_body_hash).tap do |t|
            t.delete(:description) if t[:description]
          end
        end
      end

      def auth_token_required?
        @help_widget.contact_form_require_login?
      end
  end
end

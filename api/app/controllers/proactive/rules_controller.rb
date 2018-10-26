module Proactive
  class RulesController < ApiApplicationController
    include ::Proactive::ProactiveJwtAuth
    include ::Proactive::Constants
    include ::Proactive::ProactiveUtil

    include Helpdesk::TagMethods

    ROOT_KEY = :proactive_rule

    before_filter :check_proactive_feature, :generate_jwt_token
    skip_before_filter :build_object, only: [:create]
    skip_before_filter :load_object, only: [:destroy, :show, :update, :placeholders, :preview_email]

    def create
      if email_action?
        build_ticket_object # for validation
        ticket_delegator = TicketDelegator.new(@ticket_item, ticket_fields: @ticket_fields,
          custom_fields: @email_action_params[:custom_field], tags: @email_action_params[:tags]) # add inline_attachment_ids: @inline_attachment_ids
          if !ticket_delegator.valid?(:create)
            render_custom_errors(ticket_delegator, true)
            return
          end
      end

      service_response = make_http_call(PROACTIVE_SERVICE_ROUTES[:rules_route], 'post')
      render :create, status: service_response[:status]
    end

    def index
      request_params = ''
      request_params += "per_page=#{params[:per_page]}&" if params[:per_page].present?
      request_params += "page=#{params[:page]}&" if params[:page].present?
      route = request_params == '' ? PROACTIVE_SERVICE_ROUTES[:rules_route] : "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}?#{request_params.chop}"
      service_response = make_http_call(route, 'get')
      add_link_header(page: (page.to_i + 1)) if service_response[:headers].present? && service_response[:headers]['link'].present?
      render :index, status: service_response[:status]
    end

    def show
      make_rud_request('get', 'show')
    end

    def update
      if email_action?
        build_ticket_object # for validation
        ticket_delegator = TicketDelegator.new(@ticket_item, ticket_fields: @ticket_fields,
          custom_fields: @email_action_params[:custom_field], tags: @email_action_params[:tags]) # add inline_attachment_ids: @inline_attachment_ids
          if !ticket_delegator.valid?(:create)
            render_custom_errors(ticket_delegator, true)
            return
          end
      end
      make_rud_request('put', 'update')
    end

    def destroy
      make_rud_request('delete', 'destroy')
    end

    def placeholders
      route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/placeholders"
      service_response = make_http_call(route, 'post')
      @item = { shopify: @item }
      render :placeholders, status: service_response[:status]
    end

    def preview_email
      route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/placeholders"
      service_response = make_http_call(route, 'post')
      shopify_default_values = {}
      @item.each do |placeholder|
        shopify_default_values["shopify." + placeholder["name"]] = placeholder["dummy_value"]
      end
      preview = NotificationPreview.new
      preview.add_custom_preview_hash(shopify_default_values)
      message = preview.notification_preview(cname_params[:email_body])
      @email_body = { email_body: message }
      render :preview_email, status: service_response[:status]
    end

    private

      def make_rud_request(request_method, type)
        route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/#{params[:id]}"
        service_response = make_http_call(route, request_method)
        if @item.present?
          render type.to_sym, status: service_response[:status]
        else
          head service_response[:status]
        end
      end

      def generate_jwt_token
        jwt_payload = { account_id: current_account.id, sub: 'helpkit' }
        @auth = "Token #{sign_payload(jwt_payload)}"
      end

      def check_proactive_feature
        render_request_error(:require_feature, 403, feature: 'Proactive Support') unless current_account.proactive_outreach_enabled?
      end

      def validate_params
        return unless email_action?
        @email_action_params = params[cname][:action][:email].except(:schedule_details).dup

        # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
        @ticket_fields = Account.current.ticket_fields_from_cache
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
        # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        field = ("ApiTicketConstants::COMPOSE_EMAIL_FIELDS".constantize | ['custom_fields' => custom_fields]) - RuleConstants::ATTACHMENT_FIELDS
        @email_action_params.permit(*field)
        set_default_values
        params_hash = @email_action_params.merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        ticket = TicketValidation.new(params_hash, @ticket_item, string_request_params?)
        render_custom_errors(ticket, true) unless ticket.valid?('compose_email'.to_sym)
      end

      def sanitize_params
        return unless email_action?
        prepare_array_fields(ApiTicketConstants::ARRAY_FIELDS - ['tags']) # Tags not included as it requires more manipulation.

        # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
        cc_emails =  @email_action_params[:cc_emails]
        # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
        @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup, tkt_cc: cc_emails.dup } unless cc_emails.nil?

        if @email_action_params[:custom_fields]
          checkbox_names = TicketsValidationHelper.custom_checkbox_names(@ticket_fields)
          ParamsHelper.assign_checkbox_value(@email_action_params[:custom_fields], checkbox_names) # check this func
        end

        params_to_be_deleted = [:cc_emails]
        ParamsHelper.clean_params(params_to_be_deleted, @email_action_params)

        # Assign original fields from api params and clean api params.
        ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, fr_due_by: :frDueBy,
                                               type: :ticket_type, parent_id: :assoc_parent_tkt_id, tracker_id: :tracker_ticket_id }, @email_action_params)
        # ParamsHelper.save_and_remove_params(self, [:cloud_files, :inline_attachment_ids], params[cname]) if private_api?

        # Sanitizing is required to avoid duplicate records, we are sanitizing here instead of validating in model to avoid extra query.
        prepare_tags

        # @email_action_params[:attachments] = @email_action_params[:attachments].map { |att| { resource: att } } if @email_action_params[:attachments]
      end

      def prepare_tags
        tags = sanitize_tags(@email_action_params[:tags]) if create? || @email_action_params.key?(:tags)
        @email_action_params[:tags] = construct_tags(tags) if tags
      end

      # def build_attachments
      #   build_normal_attachments(@ticket_item, params[cname][:attachments]) if params[cname][:attachments]
      #   build_cloud_files(@ticket_item, @cloud_files) if private_api? && @cloud_files
      # end

      def set_default_values
        if email_action?
          @email_action_params[:status] = ApiTicketConstants::CLOSED unless @email_action_params.key?(:status)
          @email_action_params[:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]
        end
        ParamsHelper.modify_custom_fields(@email_action_params[:custom_fields], @name_mapping.invert) # Using map instead of invert does not show any perf improvement.
      end

      def email_action?
        RuleConstants::EMAIL_ACTION_EVENTS.include?(cname_params[:event]) &&
         cname_params.key?(:action) && cname_params[:action].key?(:email)
      end

      def build_ticket_object
        # assign already loaded account object so that it will not be queried repeatedly in model
        account_included = ticket_scoper.attribute_names.include?('account_id')
        build_params = account_included ? { account: current_account } : {}
        @ticket_item = ticket_scoper.new(build_params.merge(@email_action_params))

        # assign account separately if it is protected_attribute.
        @ticket_item.account = current_account if account_included
      end

      def prepare_array_fields(array_fields = [])
        array_fields.each do |array_field|
          if create? || @email_action_params.key?(array_field)
            array_value = Array.wrap params[cname][array_field]
            @email_action_params[array_field] = array_value.uniq.reject(&:blank?)
          end
        end
      end

      def ticket_scoper
        current_account.tickets
      end
  end
end

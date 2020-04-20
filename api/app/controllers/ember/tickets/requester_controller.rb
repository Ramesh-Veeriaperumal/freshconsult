module Ember
  module Tickets
    class RequesterController < ApiApplicationController
      include TicketConcern
      include Helpdesk::RequesterWidgetHelper
      include Helpdesk::TagMethods

      before_filter :ticket_permission?, :validate_requester_delegator

      REQUESTER_FIELDS = %w[company contact].freeze
      OBJECT_PRIVILEGE_MAP = {
        company: :manage_companies
      }.freeze
      ACTION = :requester_update

      def update
        ActiveRecord::Base.transaction do
          REQUESTER_FIELDS.each do |type|
            object = instance_variable_get("@#{type}")
            next if object.blank?

            object_type = type.to_sym
            cname_params[object_type][:customer_id] = @company.id if object_type == :contact &&
                                                                     @contact.companies.blank? &&
                                                                     add_company
            next if OBJECT_PRIVILEGE_MAP[object_type] &&
                    !user_has_privilege?(OBJECT_PRIVILEGE_MAP[object_type])
            
            render_errors(object.errors) unless object.update_attributes(cname_params[type.to_sym])
          end
          @item.update_attributes(owner_id: @company.id) if add_company
        end
        REQUESTER_FIELDS.each { |type| safe_send("#{type}_decorator") }
      rescue StandardError => e
        Rails.logger.error "Error while updating requester, Param: #{cname_params.inspect}, Error - #{e.message}"
      end

      private

        def user_has_privilege?(privilege)
          api_current_user.privilege?(privilege)
        end

        def feature_name
          FeatureConstants::REQUESTER_WIDGET
        end

        def scoper
          current_account.tickets
        end

        def load_object
          @item = scoper.find_by_param(params[:id], current_account)
          if @item
            load_ticket_contact_data
          else
            log_and_render_404
          end
          @errors = []
        end

        def load_ticket_contact_data
          @contact = @item.requester
          render_request_error(:action_restricted, 403, action: ACTION, reason: 'requester is agent') unless @contact.try(:customer?)
          @company = @item.company
          company_deleted = @item.owner_id.present? && @company.blank?
          # Need to check unassociated_company use case in old behaviour
          # @unassociated_company = @company.blank? ? false : @item.requester.companies.exclude?(@company)
          company_name = cname_params[:company].try(:[], :name)
          if @company.blank? && company_name.present? && !company_deleted
            @company ||= current_account.companies.find_by_name(company_name)
            return if @company.present?

            if user_has_privilege?(:manage_companies)
              @company = current_account.companies.new
            else
              render_request_error(:action_restricted, 403,
                                   action: ACTION,
                                   reason: 'Unsufficient privilege to create new company')
            end
          end
        end

        def validate_params
          render_request_error(:missing_params, 400) if cname_params[:contact].blank? && cname_params[:company].blank?
          cname_params.permit(*REQUESTER_FIELDS)
          REQUESTER_FIELDS.each do |type|
            next if instance_variable_get("@#{type}").blank? || cname_params[type.to_sym].blank?
            fields = current_account.safe_send("#{type}_form").custom_fields_in_widget
            instance_variable_set("@#{type}_name_mapping", CustomFieldDecorator.name_mapping(fields))

            object_name_mapping = instance_variable_get("@#{type}_name_mapping")
            custom_fields = object_name_mapping.empty? ? [nil] : object_name_mapping.values
            allowed_fields = safe_send("requester_#{type}_fields") | ['custom_fields' => custom_fields]
            cname_params[type.to_sym].permit(*allowed_fields.compact)

            ParamsHelper.modify_custom_fields(cname_params[type.to_sym][:custom_fields], object_name_mapping.invert)
            requester = safe_send("#{type}_validation")
            requester_error_messages(requester, type) unless requester.valid?(ACTION)
          end
          render_requester_errors if @errors.present? && @error.blank?
        end

        def sanitize_params
          params_hash = cname_params
          params_hash[:contact][:tag_names] = sanitize_tags(params_hash[:contact].delete(:tags)).join(',') if params_hash[:contact].key?(:tags)
          REQUESTER_FIELDS.each do |type|
            next if instance_variable_get("@#{type}").blank?
            ParamsHelper.assign_checkbox_value(
              params_hash[type.to_sym][:custom_fields],
              current_account.safe_send("#{type}_form").custom_checkbox_fields.map(&:name)
            ) if params_hash[type.to_sym][:custom_fields]
            ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params_hash[type.to_sym])
          end
        end

        def validate_requester_delegator
          REQUESTER_FIELDS.each do |type|
            object = instance_variable_get("@#{type}")
            next if object.blank?
            custom_fields = cname_params[type.to_sym][:custom_field]
            object.assign_attributes(cname_params[type.to_sym])
            requester_delegator = safe_send("#{type}_delegator", custom_fields)
            requester_error_messages(requester_delegator, type) unless requester_delegator.valid?(ACTION)
          end
          render_requester_errors if @errors.present?
        end

        def requester_error_messages(item, type)
          requester_fields = "#{type.to_s.camelcase}Constants::FIELD_MAPPINGS".constantize.merge(instance_variable_get("@#{type}_name_mapping" || {}))
          options = ErrorHelper.rename_error_fields(requester_fields, item)
          Array.wrap(options.delete(:remove)).each { |field| item.errors[field].clear } if options
          if item.error_options
            ErrorHelper.rename_keys(requester_fields, item.error_options)
            (options ||= {}).merge!(item.error_options)
          end
          messages = ErrorHelper.format_error(item.errors, options)
          @errors << messages.each { |m| m.field = "#{type}.#{m.field}" }
        end

        def contact_validation
          cname_params[:contact][:action] = :requester_update
          ContactValidation.new(cname_params[:contact], @contact, string_request_params?)
        end

        def company_validation
          ApiCompanyValidation.new(cname_params[:company], @company)
        end

        def contact_delegator(custom_fields)
          ContactDelegator.new(@contact, custom_fields: custom_fields)
        end

        def company_delegator(custom_fields)
          CompanyDelegator.new(@company, custom_fields: custom_fields)
        end

        def contact_decorator
          @contact = ContactDecorator.new(@contact, name_mapping: @contact_name_mapping) if @contact.present?
        end

        def company_decorator
          @company = CompanyDecorator.new(@company, name_mapping: @company_name_mapping) if @company.present?
        end

        def render_requester_errors
          log_error_response @errors.flatten!
          render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
        end

        def add_company
          @add_company ||= @company.present? && @item.company.blank?
        end

        wrap_parameters(*wrap_params)
    end
  end
end

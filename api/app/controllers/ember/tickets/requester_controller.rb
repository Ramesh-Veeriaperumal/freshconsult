module Ember
  module Tickets
    class RequesterController < ApiApplicationController
      include TicketConcern
      include Helpdesk::RequesterWidgetHelper
      include Helpdesk::TagMethods

      before_filter :ticket_permission?, :validate_requester_delegator

      REQUESTER_FIELDS = %w(contact company).freeze
      ACTION = :requester_update

      def update
        ActiveRecord::Base.transaction do
          REQUESTER_FIELDS.each do |type|
            object = instance_variable_get("@#{type}")
            next if object.blank?
            render_errors(object.errors) unless object.update_attributes(cname_params[type.to_sym])
            send("#{type}_decorator")
          end
        end
      end

      private

        def feature_name
          FeatureConstants::REQUESTER_WIDGET
        end

        def scoper
          current_account.tickets
        end

        def load_object
          @item = scoper.find_by_param(params[:id], current_account)
          if @item
            @contact = @item.requester
            @company = @item.company
            company_name = cname_params[:company].try(:[], :name)
            @company ||= current_account.companies.find_by_name(company_name) if company_name
            @errors = []
          else
            log_and_render_404
          end
        end

        def validate_params
          render_request_error(:missing_params, 400) if cname_params[:contact].blank? && cname_params[:company].blank?
          cname_params.permit(*REQUESTER_FIELDS)
          REQUESTER_FIELDS.each do |type|
            next if instance_variable_get("@#{type}").blank?
            fields = current_account.send("#{type}_form").custom_fields_in_widget
            instance_variable_set("@#{type}_name_mapping", CustomFieldDecorator.name_mapping(fields))

            object_name_mapping = instance_variable_get("@#{type}_name_mapping")
            custom_fields = object_name_mapping.empty? ? [nil] : object_name_mapping.values
            allowed_fields = send("requester_#{type}_fields") | ['custom_fields' => custom_fields]
            cname_params[type.to_sym].permit(*allowed_fields.compact)

            ParamsHelper.modify_custom_fields(cname_params[type.to_sym][:custom_fields], object_name_mapping.invert)
            requester = send("#{type}_validation")
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
              current_account.send("#{type}_form").custom_checkbox_fields.map(&:name)
            ) if params_hash[type.to_sym][:custom_fields]
            ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params_hash[type.to_sym])
          end
        end

        def validate_requester_delegator
          REQUESTER_FIELDS.each do |type|
            object = instance_variable_get("@#{type}")
            next if object.blank?
            custom_fields = cname_params[type.to_sym].delete(:custom_field)
            object.assign_attributes(custom_field: custom_fields)
            requester_delegator = send("#{type}_delegator", custom_fields)
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
          @contact = ContactDecorator.new(@contact, name_mapping: @contact_name_mapping)
        end

        def company_decorator
          @company = CompanyDecorator.new(@company, name_mapping: @company_name_mapping)
        end

        def render_requester_errors
          log_error_response @errors.flatten!
          render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
        end

        wrap_parameters(*wrap_params)
    end
  end
end

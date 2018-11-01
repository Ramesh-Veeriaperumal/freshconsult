module Channel
  class ApiContactsController < ::ApiContactsController
    include ChannelAuthentication

    skip_before_filter :check_privilege, only: :show
    skip_before_filter :load_object, :after_load_object, only: :fetch_contact_by_email
    skip_before_filter :check_privilege, if: :channel_twitter?
    skip_before_filter :check_privilege, if: :channel_proactive?
    before_filter :channel_client_authentication

    def create
      assign_protected
      delegator_params = {
        other_emails: @email_objects[:old_email_objects],
        primary_email: @email_objects[:primary_email],
        custom_fields: params[cname][:custom_field],
        default_company: @company_id
      }
      contact_delegator = ContactDelegator.new(@item, delegator_params)
      if !contact_delegator.valid?(:channel_contact_create)
        render_custom_errors(contact_delegator, true)
      else
        build_user_emails_attributes if @email_objects.any?
        build_other_companies if @all_companies
        if @item.create_contact!(params["active"])
          render_201_with_location(item_id: @item.id)
        else
          render_custom_errors
        end
      end
    end

    def fetch_contact_by_email
      @item = current_account.contacts.find_by_email(params[:email])
      if @item.present?
        decorate_object
        render :fetch_contact_by_email, status: :ok
      else
        head 404
      end
    end

    private

      def validate_params
        @contact_fields = current_account.contact_form.custom_contact_fields
        @name_mapping = CustomFieldDecorator.name_mapping(@contact_fields)
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values

        field = ContactConstants::CONTACT_FIELDS | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
        contact = ContactValidation.new(params[cname], @item, string_request_params?)
        render_custom_errors(contact, true) unless contact.valid?(:channel_contact_create)
      end

      def validate_filter_params
        if channel_twitter?
          params.permit(*ContactConstants::CHANNEL_INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
          @contact_filter = ContactFilterValidation.new(params, nil, string_request_params?)
          render_errors(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
        else
          super
        end
      end

      def contacts_filter_conditions
        params[:twitter_id].present? ? @contact_filter.conditions.push(:twitter_id) : super
      end
  end
end

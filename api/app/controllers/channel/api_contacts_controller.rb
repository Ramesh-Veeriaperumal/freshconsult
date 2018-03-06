module Channel
  class ApiContactsController < ::ApiContactsController
    include ChannelAuthentication

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
  end
end

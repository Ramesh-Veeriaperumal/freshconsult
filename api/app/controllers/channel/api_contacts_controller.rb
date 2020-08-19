module Channel
  class ApiContactsController < ::ApiContactsController
    include ChannelAuthentication
    decorate_views

    skip_before_filter :check_privilege, only: :show
    skip_before_filter :load_object, :after_load_object, only: :fetch_contact_by_email
    skip_before_filter :check_privilege, if: :skip_privilege_check?
    before_filter :channel_client_authentication

    def create
      assign_protected
      delegator_params = {
        other_emails: @email_objects[:old_email_objects],
        primary_email: @email_objects[:primary_email],
        custom_fields: params[cname][:custom_field],
        default_company: @company_id
      }
      delegator_params.merge!(twitter_requester_fields_hash)
      contact_delegator = ContactDelegator.new(@item, delegator_params)
      if !contact_delegator.valid?(delegation_context)
        render_custom_errors(contact_delegator, true)
      else
        build_user_emails_attributes if @email_objects.any?
        build_other_companies if @all_companies
        assign_uniqueness_validated
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

      def delegation_context
        :channel_contact
      end

      def validate_params
        @contact_fields = current_account.contact_form.custom_contact_fields
        @name_mapping = CustomFieldDecorator.name_mapping(@contact_fields)
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        field = "Channel::V2::ContactConstants::CHANNEL_#{action.to_s.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
        contact = Channel::V2::ContactValidation.new(params[cname], @item,
                                                     string_request_params?)
        render_custom_errors(contact, true) unless contact.valid?(delegation_context)
      end

      def validate_filter_params
        if channel_source?(:twitter) || channel_source?(:facebook)
          params.permit(*ContactConstants::CHANNEL_INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
          @contact_filter = ContactFilterValidation.new(params, nil, string_request_params?)
          render_errors(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
        else
          super
        end
      end

      def contacts_filter_conditions
        attribute = if params[:twitter_id]
                      :twitter_id
                    elsif params[:facebook_id]
                      :facebook_id
                    end
        return @contact_filter.conditions.push(attribute) if attribute
        super
      end

      def assign_protected
        Channel::V2::ContactConstants::PROTECTED_FIELDS.each do |field|
          @item.safe_send("#{field}=", params[cname][field]) if params[cname][field].present? && @item.respond_to?(field)
        end
        @item.fb_profile_id = params[cname][:facebook_id].presence
        @item.merge_preferences = params[:preferences] if params.key?(:preferences)
        super
      end

      def decorator_options(options = {})
        options[:additional_info] = channel_source?(:freshmover)
        super(options)
      end

      def skip_privilege_check?
        channel_source?(:twitter) || channel_source?(:proactive) || channel_source?(:facebook) || channel_source?(:multiplexer)
      end

      def twitter_requester_fields_hash
        {
          twitter_profile_status: params[cname][:twitter_profile_status],
          twitter_followers_count: params[cname][:twitter_followers_count]
        }
      end
  end
end

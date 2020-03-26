module Channel::V2
  class TicketsController < ::TicketsController

    CHANNEL_V2_TICKETS_CONSTANTS_CLASS = 'Channel::V2::TicketConstants'.freeze

    private

    def ticket_delegator_class
      'Channel::V2::TicketDelegator'.constantize
    end

    def constants_class
      CHANNEL_V2_TICKETS_CONSTANTS_CLASS
    end

    def validation_class
      Channel::V2::TicketValidation
    end

    def validate_params
      custom_number_fields = []
      # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
      @ticket_fields = ::Account.current.ticket_fields_from_cache
      @ticket_fields.each do |field|
        if field.field_type == 'custom_number'
          custom_number_fields.push(field.name)
        end
        field.required = false
      end

      @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      social_field = identify_social_field
      field = "#{constants_class}::#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields] | ['source_additional_info' => social_field]
      params[cname].permit(*field)
      set_default_values
      params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)

      if params_hash[:custom_fields].present? && params_hash[:custom_fields].is_a?(Hash)
        custom_fields = params_hash[:custom_fields]
        custom_number_fields.each do |field_name|
          value = custom_fields[field_name]
          custom_fields[field_name] = Integer(value) rescue value if value.present?
        end
      end

      if params_hash[:source_additional_info].present? && params_hash[:source_additional_info].is_a?(Hash)
        params_hash[:facebook] = params_hash[:source_additional_info][:facebook] if facebook_ticket?
        params_hash[:twitter] = params_hash[:source_additional_info][:twitter] if twitter_ticket?
      end

      ticket = validation_class.new(params_hash, @item, string_request_params?)
      render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
    end

    def sanitize_params
      super
      Channel::V2::TicketConstants::ASSOCIATE_ATTRIBUTES.each do |attribute|
        instance_variable_set("@#{attribute.to_s}",
                              params[cname].delete(attribute)) if params[cname].key?(attribute)
      end
      if create_action? && facebook_ticket?
        @facebook = params[cname][:source_additional_info][:facebook]
        if @facebook.present?
          page = ::Account.current.facebook_pages.where(:page_id=>@facebook[:page_id]).first
          @facebook[:page_id] = (page.present? && page.id) ? page.id : nil
        end
      end

      if create_action? && twitter_ticket?
        @tweet = params[cname][:source_additional_info][:twitter]
        if @tweet.present?
          handle = ::Account.current.twitter_handles.where(twitter_user_id: @tweet[:support_handle_id]).first
          @tweet[:twitter_handle_id] = handle.present? && handle.id ? handle.id : nil
        end
      end
      params[cname].delete(:source_additional_info)
    end

    def identify_social_field
      if create_action? && params[cname][:source].present?
        return ['facebook'] if facebook_ticket?
        return ['twitter'] if twitter_ticket?
      end
      return [nil]
    end

    def create_action?
      action_name == 'create'
    end

    def facebook_ticket?
      params[cname][:source] == current_account.helpdesk_sources.ticket_source_keys_by_token[:facebook]
    end

    def twitter_ticket?
      params[cname][:source] == current_account.helpdesk_sources.ticket_source_keys_by_token[:twitter]
    end

    def set_default_values
      super
      params[cname][:status] = ApiTicketConstants::OPEN if !@item.try("id") && !params[cname].key?(:status)
    end

    def assign_protected
      super
      set_attribute_accessors
      @item.display_id = @display_id if @display_id.present?
      @item.import_id = @import_id if @import_id.present?
      assign_ticket_states
      assign_fb_attributes if @facebook.present?
      assign_twitter_attributes if @tweet.present?
    end

    def assign_fb_attributes
      facebook_dm_ticket? ? build_fb_dm_attributes : build_fb_post_attributes
    end

    def build_fb_post_attributes
      @item.fb_post = Social::FbPost.new(
            :post_id => @facebook[:post_id],
            :facebook_page_id => @facebook[:page_id],
            :post_attributes => post_attributes
          )
    end

    def build_fb_dm_attributes
      @item.fb_post = Social::FbPost.new(
            :post_id => @facebook[:post_id],
            :facebook_page_id => @facebook[:page_id],
            :msg_type => @facebook[:msg_type],
            :thread_id => @facebook[:thread_id],
            :thread_key => @facebook[:thread_id]
          )
    end

    def post_attributes
      post_attributes = HashWithIndifferentAccess.new
      post_attributes['can_comment'] = @facebook[:can_comment]
      post_attributes['post_type'] = @facebook[:post_type]
      post_attributes
    end

    def facebook_dm_ticket?
      @facebook[:msg_type].present? && @facebook[:msg_type] == Channel::V2::TicketConstants::FB_MSG_TYPES[0]
    end

    def assign_twitter_attributes
      build_twitter_attributes
    end

    def build_twitter_attributes
      @item.tweet = Social::Tweet.new(tweet_id: @tweet[:tweet_id],
                                      tweet_type: @tweet[:tweet_type],
                                      twitter_handle_id: @tweet[:twitter_handle_id],
                                      stream_id: @tweet[:stream_id])
    end

    def set_attribute_accessors
      if @import_id.present?
        @item.import_ticket = true
        if @item.due_by.present? || @item.frDueBy.present?
          @item.due_by = @item.frDueBy unless @item.due_by.present?
          @item.frDueBy = @item.due_by unless @item.frDueBy.present?
          @item.disable_sla_calculation = true
        else
          created_time = Time.parse(params[cname]['created_at']) rescue nil
          if @item.status == CLOSED
            due_by = @closed_at || ((created_time || Time.zone.now) + 1.month)
            @item.due_by = due_by
            @item.frDueBy = due_by
            @item.disable_sla_calculation = true
          elsif created_time.present?
            if created_time < (Time.zone.now - 1.month)
              due_by = (created_time || Time.zone.now) + 1.month
              @item.due_by = due_by
              @item.frDueBy = due_by
              @item.disable_sla_calculation = true
            else
              @item.sla_calculation_time = created_time
            end
          end
        end
      end
    end

    def assign_on_state_time
      @item.build_ticket_states
      @item.ticket_states.on_state_time = @on_state_time
    end

    def assign_ticket_states
      assign_on_state_time if create?
      Channel::V2::TicketConstants::ACCESSIBLE_ATTRIBUTES.each do |attribute|
        if instance_variable_get("@#{attribute}").present?
          @item.ticket_states.safe_send("#{attribute}=", instance_variable_get("@#{attribute}"))
        end
      end
    end
  end
end

class TicketsController < ApiApplicationController
  include Helpdesk::TicketActions
  include Concerns::TicketConcern
  include Helpdesk::TagMethods

  before_filter :assign_protected, only: [:create]

  def create
    add_ticket_tags(@tags, @item) if @tags # Tags need to be built if not already available for teh account.
    if @item.save_ticket
      render '/tickets/create', location: send("#{nscname}_url", @item.id), status: 201
      notify_cc_people params[cname][:cc_email] unless params[cname][:cc_email].blank?
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  private

    def scoper
      current_account.tickets
    end

    def manipulate_params
      params[cname][:cc_email] = { cc_emails: params[cname][:cc_emails] }
      params[cname][:custom_field] = params[cname][:custom_fields]
      params[cname][:frDueBy] = params[cname][:fr_due_by]
      params[cname][:manual_dueby] = true if params[cname][:due_by] && params[cname][:fr_due_by]
      @tags = params[cname][:tags].map(&:strip) if params[cname][:tags]
      clean_params([:cc_emails, :custom_fields, :tags, :fr_due_by])
      build_ticket_body_attributes
    end

    def validate_params
      allowed_custom_fields = TicketsValidationHelper.ticket_custom_field_keys(current_account)
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = "ApiConstants::#{action_name.upcase}_TICKET_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ticket = TicketValidation.new(params[cname], nil, current_account)
      render_error ticket.errors unless ticket.valid?
    end

    def assign_protected
      @item.product ||= current_portal.product
      @item.display_id = params[cname][:display_id]
      # build_attachments @item, cname.to_sym # Attachments should be part of same action.
    end

    def clean_params(params_to_be_deleted)
      params_to_be_deleted.each do |field|
        params[cname].delete(field)
      end
    end
end

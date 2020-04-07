module TicketUpdateHelper
  include HelperConcern
  include TicketConcern

  def validate_and_assign
    # attachment_attributes is a hash of attachment_ids and shared_attachments.
    delegator_hash = Hash.new.tap do |hash|
      hash[:ticket_fields] = @ticket_fields
      hash[:custom_fields] = ticket_update_params[:custom_field]
      hash[:company_id] = ticket_update_params[:company_id]
      hash[:enforce_mandatory] =  params[:enforce_mandatory]
      hash[:tracker_ticket_id] = ticket_update_params[:tracker_ticket_id] if link_or_unlink?
    end.merge!(attachment_attributes || {})

    assign_attributes_for_update
    # we cannot use validate_delegator here as @delegator_class will take constant class from base controller.
    @ticket_delegator = TicketDelegator.new(ticket, delegator_hash)
    render_custom_errors(@ticket_delegator, true) && return unless @ticket_delegator.valid?(:update)

    modify_ticket_associations if link_or_unlink?
    ticket.attachments = ticket.attachments + @ticket_delegator.draft_attachments if @ticket_delegator.draft_attachments
    true
  end

  private

    def assign_attributes_for_update
      ticket.assign_attributes(validatable_delegator_attributes)
      ticket.assign_description_html(ticket_update_params[:ticket_body_attributes]) if ticket_update_params[:ticket_body_attributes]
    end

    def validatable_delegator_attributes
      ticket_update_params.select do |key, value|
        if ApiTicketConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(key)
          ticket_update_params.delete(key)
          true
        end
      end
    end

    def ticket_update_params
      @ticket_params || cname_params
    end

    def ticket
      @ticket || @item
    end

    def attachment_attributes
      # These attributes are merged with the delegator_hash
      {
        attachment_ids: @attachment_ids,
        shared_attachments: shared_attachments
      }
    end
end

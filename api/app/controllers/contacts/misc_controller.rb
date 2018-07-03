class Contacts::MiscController < ApiApplicationController
  include HelperConcern
  def send_invite
    send_activation_mail(@item) ? (head 204) : render_errors(@contact_delegator.errors, @contact_delegator.error_options)
  end

  private

    def scoper
      current_account.all_contacts
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id])
      @item ||= deleted_agent

      log_and_render_404 unless @item
    end

    def deleted_agent
      @deleted_agent ||= current_account.all_users.where(deleted: true, helpdesk_agent: true).find_by_id(params[:id])
    end

    def send_activation_mail(item)
      @contact_delegator = ContactDelegator.new(item)
      valid = @contact_delegator.valid?(:send_invite)
      item.deliver_activation_instructions!(current_portal, true) if valid && item.has_email?
      valid
    end

    def constants_class
      :ContactConstants.to_s.freeze
    end
end

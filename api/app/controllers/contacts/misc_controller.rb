class Contacts::MiscController < ApiApplicationController
  EXPORT_TYPE = 'contact'.freeze

  include HelperConcern
  include ContactsCompaniesConcern
  include Export::Util

  before_filter :export_limit_reached?, only: [:export]
  before_filter :load_data_export, only: [:export_details]

  def send_invite
    send_activation_mail(@item) ? (head 204) : render_errors(@contact_delegator.errors, @contact_delegator.error_options)
  end

  def export
    contact_company_export EXPORT_TYPE
  end

  def export_details
    fetch_export_details
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

    def load_data_export
      fetch_data_export_item EXPORT_TYPE
    end

    def export_limit_reached?
      check_export_limit EXPORT_TYPE
    end

    def constants_class
      :ContactConstants.to_s.freeze
    end
end

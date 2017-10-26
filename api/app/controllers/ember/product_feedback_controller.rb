class Ember::ProductFeedbackController < ApiApplicationController
  include Helpdesk::TicketActions
  include ActionView::Helpers::TextHelper
  include HelperConcern
  include TicketConstants

  skip_before_filter :build_object, only: [:create]

  # validate and sanitize gets called before create
  def create
    ProductFeedbackWorker.perform_async(request_payload)
    head 204
  end

  private

    def constants_class
      :ProductFeedbackConstants.to_s.freeze
    end

    def request_payload
      description = simple_format(params[cname][:description]) + '<br><br>'.html_safe + account_details.html_safe
      {
        email: current_user.email,
        subject: params[cname][:subject] || "Feedback from #{current_user.name}(#{current_user.email})",
        status: Helpdesk::Ticketfields::TicketStatus::OPEN,
        priority: PRIORITY_KEYS_BY_TOKEN[:low],
        description: description,
        source: SOURCE_KEYS_BY_TOKEN[:feedback_widget],
        tags: params[cname][:tags],
        attachment_ids: params[cname][:attachment_ids]
      }
    end

    def account_details
      "<p><b>Account ID</b>: #{current_account.id}</p>" \
      "<p><b>Account URL</b>: #{current_account.full_domain}</p>" \
      "<p><b>Admin</b>: #{current_user.privilege?(:admin_tasks)}</p>"
    end

    # putting validate body params inside validate params so that validation takes place before sanitization
    def validate_params
      validate_body_params
    end

    def sanitize_params
      [:subject, :description].each do |field|
        params[cname][field] = RailsFullSanitizer.sanitize params[cname][field] if params[cname][field].present?
      end
      [:tags, :attachment_ids].each do |field|
        params[cname][field].uniq! if params[cname][field].present?
      end
    end
end

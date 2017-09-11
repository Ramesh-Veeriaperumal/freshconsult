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

    def request_payload
      description = simple_format(params[:product_feedback][:description]) +
                    '<br><br>'.html_safe +
                    account_details.html_safe

      {
        email: current_user.email,
        subject: "Falcon feedback from #{current_user.name}(#{current_user.email})",
        status: Helpdesk::Ticketfields::TicketStatus::OPEN,
        priority: PRIORITY_KEYS_BY_TOKEN[:low],
        description: description,
        source: SOURCE_KEYS_BY_TOKEN[:feedback_widget],
        tags: ['falcon_feedback', current_account.id.to_s],
        attachment_ids: params[:product_feedback][:attachment_ids]
      }
    end

    def account_details
      "<p><b>Account ID</b>: #{current_account.id}</p>" \
        "<p><b>Account URL</b>: #{current_account.full_domain}</p>" \
        "<p><b>Admin</b>: #{current_user.privilege?(:admin_tasks)}</p>"
    end

    def validate_params
      params.require(:product_feedback).permit(:description, :attachment_ids)
      feedback = ProductFeedbackValidation.new(params[:product_feedback], nil, true)
      render_errors(feedback.errors, feedback.error_options) unless feedback.valid?
    end

    def sanitize_params
      params[:product_feedback][:description] = RailsFullSanitizer.sanitize params[:product_feedback][:description] if params[:product_feedback][:description].present?
      params[:product_feedback][:attachment_ids].uniq! if params[:product_feedback][:attachment_ids].present?
    end
end

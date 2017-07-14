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
      description = simple_format(params[:description]) +
                    '<br><br>'.html_safe +
                    account_details.html_safe
      
      {
        email: current_user.email,
        subject: "Falcon feedback from #{current_user.name}(#{current_user.email})",
        status: Helpdesk::Ticketfields::TicketStatus::OPEN,
        priority: PRIORITY_KEYS_BY_TOKEN[:low],
        description: description,
        source: SOURCE_KEYS_BY_TOKEN[:feedback_widget],
        tags: ['falcon_feedback', current_account.id.to_s]
      }
    end

    def account_details
      "<p><b>Account ID</b>: #{current_account.id}</p>" \
        "<p><b>Account URL</b>: #{current_account.full_domain}</p>" \
        "<p><b>Admin</b>: #{current_user.privilege?(:admin_tasks)}</p>"
    end

    def validate_params
      feedback = ProductFeedbackValidation.new(params, nil, true)
      render_errors(feedback.errors, feedback.error_options) unless feedback.valid?
    end

    def sanitize_params
      params[:description] = RailsFullSanitizer.sanitize params[:description] if params[:description].present?
    end
end

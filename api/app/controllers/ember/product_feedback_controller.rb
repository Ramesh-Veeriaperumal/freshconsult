class Ember::ProductFeedbackController < ApiApplicationController
  include Helpdesk::TicketActions
  include ActionView::Helpers::TextHelper
  include HelperConcern
  include TicketConstants

  skip_before_filter :build_object, only: [:create]
  skip_before_filter :check_account_state

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
      description = simple_format(params[cname][:description]) + '<br>'.html_safe + account_details.html_safe
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
      "<p>Below are the account details:<p>" \
      "<p><b>Name</b>: #{current_user.name}</p>" \
      "<p><b>Email</b>: #{current_user.email}</p>" \
      "<p><b>Account Name</b>: #{current_account.name}</p>" \
      "<p><b>Account ID</b>: #{current_account.id}</p>" \
      "<p><b>Account URL</b>: #{current_account.full_domain}</p>" \
      "<p><b>Plan</b>: #{current_account.subscription.plan_name}</p>" \
      "<p><b>Admin</b>: #{current_user.privilege?(:admin_tasks)}</p>" \
      "<br><p>Thanks,</p><p>Freshdesk Product</p>"
    end

    # putting validate body params inside validate params so that validation takes place before sanitization
    def validate_params
      validate_body_params
    end

    def sanitize_params
      [:subject, :description].each do |field|
        params[cname][field] = Helpdesk::HTMLSanitizer.clean(params[cname][field]) if params[cname][field].present?
      end
      [:tags, :attachment_ids].each do |field|
        params[cname][field].uniq! if params[cname][field].present?
      end
    end
end

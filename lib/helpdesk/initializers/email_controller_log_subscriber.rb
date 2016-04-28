class EmailControllerLogSubscriber < ActiveSupport::LogSubscriber
  include EmailCustomLogger

  def start_processing(event)
    payload = event.payload

    if is_log_reduce_controller? payload[:controller]
      email_params = payload[:params]
      c_params = exclude_params(payload[:controller], payload[:params])
    else
      email_params = {}
      c_params = payload[:params]
    end

    format = payload[:format]
    format = format.to_s.upcase if format.is_a?(Symbol)

    logger.info "Processing by #{payload[:controller]}##{payload[:action]} as #{format}"

    logger.info "  Parameters: #{c_params.inspect}" unless c_params.empty?
    email_logger.info "  Parameters: #{email_params.inspect}" unless email_params.empty?
  end

  def exclude_params(controller_name, controller_params)
    f_params = {}
    case controller_name
    when "EmailController"
      f_params = controller_params.except("text", "html")
    when "MailgunController"
      f_params = controller_params.except("body-html", "body-plain", "stripped-html", "stripped-text")
    when "Helpdesk::ConversationsController"
      params_copy = controller_params.deep_dup
      if params_copy[:helpdesk_note].present? && params_copy[:helpdesk_note][:note_body_attributes].present?
        params_copy[:helpdesk_note][:note_body_attributes].delete(:body)
        params_copy[:helpdesk_note][:note_body_attributes].delete(:body_html)
        params_copy[:helpdesk_note][:note_body_attributes].delete(:full_text)
        params_copy[:helpdesk_note][:note_body_attributes].delete(:full_text_html)
        params_copy[:helpdesk_note][:note_body_attributes].delete(:quoted_text_html)
      end
      f_params = params_copy
    end
    f_params
  end

  def is_log_reduce_controller?(controller_name)
    ["EmailController", "MailgunController", "Helpdesk::ConversationsController"].any? {|controller| (controller == controller_name)}
  end
end

ActiveSupport::Notifications.unsubscribe "start_processing.action_controller"

EmailControllerLogSubscriber.attach_to :action_controller

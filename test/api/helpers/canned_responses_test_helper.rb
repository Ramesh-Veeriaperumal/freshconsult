module CannedResponsesTestHelper
  def ca_response_show_pattern(ca_response_id = nil, attachments = [])
    ca_response = @account.canned_responses.find(ca_response_id)
    {
      id: ca_response.id,
      title: ca_response.title,
      content: ca_response.content,
      content_html: ca_response.content_html,
      folder_id: ca_response.folder_id,
      attachments: attachments.map do |attachment|
        attachment_pattern(attachment)
      end
    }
  end

  def ca_response_show_pattern_evaluated_content(ca_response_id = nil, ticket = nil, attachments = [])
    ca_pattern = ca_response_show_pattern(ca_response_id, attachments)
    ca_pattern.merge!(evaluated_response: evaluate_response(ca_pattern[:content_html], ticket))
  end

  def ca_response_show_pattern_new_ticket(ca_response_id = nil, attachments = [])
    ca_pattern = ca_response_show_pattern(ca_response_id, attachments)
    ca_pattern.merge!(evaluated_response: evaluate_response_new_ticket(ca_pattern[:content_html]))
  end

  def user_stub_ticket_permission
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
  end

  def user_unstub_ticket_permission
    User.any_instance.unstub(:can_view_all_tickets?)
    User.any_instance.unstub(:group_ticket_permission)
    User.any_instance.unstub(:assigned_ticket_permission)
  end

  def evaluate_response(content_html, ticket)
    Liquid::Template.parse(content_html).render({ ticket: ticket, helpdesk_name: ticket.account.portal_name }.stringify_keys)
  end

  def evaluate_response_new_ticket(content_html)
    Liquid::Template.parse(content_html).render(ticket: nil)
  end
end

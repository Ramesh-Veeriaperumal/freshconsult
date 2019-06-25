module CannedResponsesTestHelper
  def ca_response_show_pattern(ca_response_id = nil, attachments = [])
    ca_response_pattern(ca_response_id).merge({
      attachments: attachments.map do |attachment|
        attachment_pattern(attachment).merge(is_shared: true)
      end
    })
  end

  def ca_response_search_pattern(ca_response_id = nil)
    ca_response_pattern(ca_response_id).slice(:id, :title, :folder_id)
  end

  def ca_response_pattern(ca_response_id = nil)
    ca_response = @account.all_canned_responses.find(ca_response_id)
    {
      id: ca_response.id,
      title: ca_response.title,
      content: ca_response.content,
      content_html: ca_response.content_html,
      folder_id: ca_response.folder_id,
      created_at: ca_response.created_at.try(:utc).try(:iso8601),
      updated_at: ca_response.updated_at.try(:utc).try(:iso8601)
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

  def create_ca_response_input(folder_id = nil, visibility = nil, group_id = nil)
    ret_hash = {
      title: Faker::Name.name,
      content_html: Faker::Name.name,
      visibility: visibility,
      group_ids: group_id
    }
    ret_hash[:folder_id] = folder_id if folder_id.present?
    ret_hash
  end

  def build_ca_param(response)
    {
      version: 'v2',
      canned_response: response
    }
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end
end

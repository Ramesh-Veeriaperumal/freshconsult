module CannedResponsesTestHelper
  def canned_responses_evaluated_pattern(strict, attachments = [], content = nil)
    if strict
      {
        content: content,
        attachments: canned_response_attachment_pattern(strict, attachments)
      }
    else
      {
        content: String,
        attachments: canned_response_attachment_pattern(strict, attachments)
      }
    end
  end

  def canned_response_attachment_pattern(strict, attachments)
    att = []
    attachments.each do |attachment|
      if strict
        att << {
          id: attachment.id,
          name: attachment.content_file_name
        }
      else
        att << {
          id: Fixnum,
          name: String
        }
      end
    end
    att
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

  def evaluate_response(ca_response, ticket)
    Liquid::Template.parse(ca_response.content_html).render({ ticket: ticket, helpdesk_name: ticket.account.portal_name }.stringify_keys)
  end
end

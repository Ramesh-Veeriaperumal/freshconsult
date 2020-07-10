require_relative '../../test_helper'

class AttachmentTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include ModelsAttachmentsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run

    @attachment = create_ticket_with_attachments
    @@before_all_run = true
  end

  def test_central_publish_payload
    ticket = create_ticket_with_attachments
    attachment = ticket.attachments.first
    payload = attachment.central_publish_payload
    payload.except(:attachment_url).to_json.must_match_json_expression(central_publish_attachment_pattern(attachment))
    assert_includes payload[:attachment_url], "/fd-testbed/data/helpdesk/attachments/test/#{attachment.id}/original/#{attachment.content_file_name}"
  end

end
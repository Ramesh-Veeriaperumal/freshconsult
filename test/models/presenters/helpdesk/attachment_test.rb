require_relative '../../test_helper'

class AttachmentTest < ActiveSupport::TestCase
	include TicketsTestHelper
	include AttachmentsTestHelper

	def setup 
		super
		before_all
	end

	@@before_all_run = false

	def before_all
		return if @@before_all_run
		@account.subscription.state = 'active'
		@account.subscription.save
		@attachment = create_ticket_with_attachments
		@@before_all_run = true
	end

	def test_central_publish_payload
	    ticket = create_ticket_with_attachments
	    attachment = ticket.attachments.first
	    payload = attachment.central_publish_payload.to_json
	    payload.must_match_json_expression(central_publish_attachment_pattern(attachment))
  	end

end
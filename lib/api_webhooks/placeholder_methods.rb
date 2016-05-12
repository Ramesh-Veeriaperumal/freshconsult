module ApiWebhooks::PlaceholderMethods

	def ticket_placeholder
    place_holders = [
      ['{{ticket.id}}','ticket_display_id'],
      ['{{ticket.raw_id}}','ticket_id'],
      ['{{ticket.subject}}','ticket_subject'],
      ['{{ticket.description}}','ticket_description_html'],
      ['{{ticket.description_text}}','ticket_description'],
      ['{{ticket.deleted}}','ticket_is_deleted'],
      ['{{ticket.url}}','ticket_url'],
      ['{{ticket.public_url}}','ticket_public_url'],
      ['{{ticket.portal_url}}','ticket_portal_url'],
      ['{{ticket.status}}','ticket_status'],
      ['{{ticket.priority}}','ticket_priority'],
      ['{{ticket.source}}','ticket_source'],
      ['{{ticket.ticket_type}}','ticket_type'],
      ['{{ticket.tags}}','ticket_tags'],
      ['{{ticket.due_by_time}}','ticket_due_by_time'],
      ['{{ticket.requester.name}}','ticket_requester_name'],
      ['{{ticket.requester.firstname}}' ,'ticket_requester_firstname'],
      ['{{ticket.requester.lastname}}' ,'ticket_requester_lastname'],
      ['{{ticket.requester.email}}','ticket_requester_email'],
      ['{{ticket.requester.company_name}}','ticket_requester_company_name'],
      ['{{ticket.requester.phone}}','ticket_requester_phone'],
      ['{{ticket.requester.address}}','ticket_requester_address'],
      ['{{ticket.group.name}}','ticket_group_name'],
      ['{{ticket.agent.name}}','ticket_agent_name'],
      ['{{ticket.agent.email}}','ticket_agent_email'],
      ['{{ticket.latest_public_comment}}','ticket_latest_public_comment'],
      ['{{ticket.latest_private_comment}}', 'ticket_latest_private_comment'],
      ['{{helpdesk_name}}','helpdesk_name'],
      ['{{ticket.portal_name}}','ticket_portal_name'],
      ['{{ticket.product_description}}','ticket_product_description']
    ]
    current_account.ticket_fields.custom_fields.each { |custom_field|
      name = custom_field.name[0..custom_field.name.rindex('_')-1]
      place_holders << ["{{ticket.#{name}}}", "ticket_#{name}"] unless name == "type"
    }
    place_holders
  end

  def note_placeholder
    place_holders = [
     ['{{note.id}}','note_id'],
     ['{{note.description_text}}','note_comment'],
     ['{{note.private}}','note_private'],
     ['{{note.commenter.name}}','note_commenter_name'],
     ['{{note.commenter.email}}','note_commenter_email'],
     ['{{note.note_ticket.id}}','ticket_display_id'],
     ['{{note.note_ticket.subject}}','ticket_subject']
    ]
    place_holders
  end

  def user_placeholder
    place_holders = [
     ['{{user.id}}','user_id'],
     ['{{user.address}}','user_address'],
     ['{{user.is_agent}}','user_agent'],
     ['{{user.first_name}}','user_firstname'],
     ['{{user.last_name}}','user_lastname'],
     ['{{user.company_name}}','user_company_name'],
     ['{{user.email}}','user_email'],
     ['{{user.active}}','user_active'],
     ['{{user.job_title}}','user_job_title'],
     ['{{user.phone}}','user_phone_number'],
     ['{{user.mobile}}','user_mobile_number'],
     ['{{user.description}}','user_description'],
     ['{{user.address}}','user_address']
    ]
    place_holders
  end
end
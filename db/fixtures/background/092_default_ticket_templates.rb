account = Account.current

account.ticket_fields.find_by_name("ticket_type").picklist_values.create(value: "Refund")

ticket_template_data = ActionController::Parameters.new(
  subject: I18n.t('fixtures.ticket_templates.name'),
  ticket_type: 'Refund',
  status: Helpdesk::TicketStatus.status_keys_by_name(account)['Open'],
  priority: Helpdesk::Ticket::PRIORITY_KEYS_BY_TOKEN[:high],
  tags: 'refund'
)

sample_template = account.ticket_templates.build(
	name: I18n.t('fixtures.ticket_templates.name'),
	description: I18n.t('fixtures.ticket_templates.desc'),
	accessible_attributes: {access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]},
	association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
	template_data: ticket_template_data
)
sample_template.data_description_html = I18n.t('fixtures.ticket_templates.content')
sample_template.save!

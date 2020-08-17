account = Account.current
# DEFAULT_TICKET_SOURCES should be updated when updating Helpdesk::Source::TICKET_SOURCES
DEFAULT_TICKET_SOURCES = [
  ['Email', 1, 1, { icon_id: 1 }],
  ['Portal', 2, 2, { icon_id: 2 }],
  ['Phone', 3, 3, { icon_id: 3 }],
  ['Forum', 4, 4, { icon_id: 4 }],
  ['Twitter', 5, 5, { icon_id: 5 }],
  ['Facebook', 6, 6, { icon_id: 6 }],
  ['Chat', 7, 7, { icon_id: 7 }],
  ['Feedback Widget', 8, 9, { icon_id: 9 }],
  ['Outbound Email', 9, 10, { icon_id: 10 }],
  ['Ecommerce', 10, 11, { icon_id: 11 }],
  ['Bot', 11, 12, { icon_id: 12 }],
  ['Whatsapp', 12, 13, { icon_id: 13 }]
].freeze
CHOICE_TYPE = 'Helpdesk::Source'.freeze
Helpdesk::Source.seed_many(:account_id, :account_choice_id,
                           DEFAULT_TICKET_SOURCES.map do |source|
                             {
                               account_id: account.id,
                               name: source[0],
                               position: source[1],
                               default: 1,
                               account_choice_id: source[2],
                               type: CHOICE_TYPE,
                               meta: HashWithIndifferentAccess.new(source[3])
                             }
                           end)

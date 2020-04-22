account = Account.current

if $redis_others.perform_redis_op('get', 'POPULATE_DEFAULT_SOURCES')
  # DEFAULT_TICKET_SOURCES should be updated when updating Helpdesk::Source::TICKET_SOURCES
  DEFAULT_TICKET_SOURCES = [
    ['Email', 1, 1],
    ['Portal', 2, 2],
    ['Phone', 3, 3],
    ['Forum', 4, 4],
    ['Twitter', 5, 5],
    ['Facebook', 6, 6],
    ['Chat', 7, 7],
    ['Mobihelp', 8, 8],
    ['Feedback Widget', 9, 9],
    ['Outbound Email', 10, 10],
    ['Ecommerce', 11, 11],
    ['Bot', 12, 12]
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
        type: CHOICE_TYPE
      }
    end
  )
end

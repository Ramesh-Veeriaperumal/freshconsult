class Helpdesk::Source < Helpdesk::Choice
  belongs_to_account
  has_many :tickets, class_name: 'Helpdesk::Ticket', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :source

  has_many :archived_tickets, class_name: 'Helpdesk::ArchiveTicket', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :source

  has_many :notes, class_name: 'Helpdesk::Note', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :source

  has_many :archive_notes, class_name: 'Helpdesk::ArchiveNote', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :source
end

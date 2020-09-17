class Helpdesk::Source < Helpdesk::Choice
  belongs_to_account
  has_many :tickets, class_name: 'Helpdesk::Ticket', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :ticket_source

  has_many :archive_tickets, class_name: 'Helpdesk::ArchiveTicket', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :ticket_source

  has_many :notes, class_name: 'Helpdesk::Note', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :note_source

  has_many :archive_notes, class_name: 'Helpdesk::ArchiveNote', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :note_source
end

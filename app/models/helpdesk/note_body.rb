# frozen_string_literal: true

class Helpdesk::NoteBody < ActiveRecord::Base
  self.table_name = 'helpdesk_note_bodies'
  self.primary_key = :id

  belongs_to_account
  belongs_to :note, class_name: 'Helpdesk::Note', foreign_key: :note_id, inverse_of: :note_body

  attr_protected :account_id
end
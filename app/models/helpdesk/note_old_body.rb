# This model will be deprecated and removed soon
# New notes created should not be stored in this table, they should be stored in riak

class Helpdesk::NoteOldBody < ActiveRecord::Base
  self.table_name =  "helpdesk_note_bodies"
  self.primary_key = :id

  belongs_to_account
  belongs_to :note, :class_name => 'Helpdesk::Note', :foreign_key => 'note_id'

  attr_protected :account_id

  #  returns false by default 
  #  preventing update a note_body in case of note update gets called in cases
  #  where note_body is not yet defined and only note_old_body is present
  def attributes_changed?
    false
  end
end
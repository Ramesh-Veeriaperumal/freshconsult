class Helpdesk::NoteBodyWeekly < Helpdesk::Mysql::DynamicTable

  def self.find_note_body(table_name,note_id,account_id)
    self.table_name = table_name
    self.find_by_note_id_and_account_id(note_id,account_id)
  end
end

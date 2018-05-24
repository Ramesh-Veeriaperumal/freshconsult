# This module is an extension for Helpdesk::Note
# This module is a wrapper between riak and mysql

class Helpdesk::Note < ActiveRecord::Base
  
  def create_in_mysql
    # creating a new record
    note_old_body = self.build_note_old_body(construct_note_old_body_hash) 
    UnicodeSanitizer.encode_emoji(note_old_body, 'body', 'full_text')
    note_old_body.save
  end

  def read_from_mysql
    return note_old_body
  end
  
  def update_in_mysql
    # case were a note without note_body is updated
    note_old_body = self.note_old_body || self.build_note_old_body
    # updating the attributes
    note_old_body.attributes = construct_note_old_body_hash
    # saving the record
    UnicodeSanitizer.encode_emoji(note_old_body, 'body', 'full_text')
    note_old_body.save
  end

  def delete_in_mysql
  end

  alias_method :rollback_in_mysql, :delete_in_mysql
end

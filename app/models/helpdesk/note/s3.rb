
class Helpdesk::Note < ActiveRecord::Base

  def create_in_s3
    # value = construct_note_old_body_hash.merge(add_created_at_and_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_note_bodies")
    # Heldpesk::NoteBodyWeekly.create(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Note::NoteBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     :create => true
                     # :table => table_name
    })
  end

  # fetching from s3
  def read_from_s3
    object= Helpdesk::S3::Note::Body.get_from_s3(self.account_id,self.id)
    s3_note_body = Helpdesk::NoteBody.new(object)
    s3_note_body.new_record = false
    s3_note_body.reset_attribute_changed
    self.previous_value = s3_note_body.clone
    return s3_note_body
  end

  def update_in_s3
    # value = construct_note_old_body_hash.merge(add_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_note_bodies")
    # value[:conditions] = {:account_id => self.account_id, :note_id => self.id}
    # Heldpesk::NoteBodyWeekly.create_or_update(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Note::UpdateNoteBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id
                     # :table => table_name
    })
  end

  def delete_in_s3
    Resque.enqueue(::Workers::Helpkit::Note::NoteBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     :delete => true
    })
  end

  alias_method :rollback_in_s3, :update_in_s3

  def add_created_at_and_updated_at
    {
      :created_at => Time.now.utc,
      :updated_at => Time.now.utc
    }
  end

  def add_updated_at
    {
      :created_at => self.created_at.to_utc,
      :updated_at => Time.now.utc
    }
  end
end

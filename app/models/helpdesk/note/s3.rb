
class Helpdesk::Note < ActiveRecord::Base

  def push_to_resque_create
    Notes::NoteBodyJobs.perform_async({:key_id => self.id, :create => true,:user_id => self.user_id})  if s3_create
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

  def push_to_resque_update
    Notes::UpdateNoteBodyJobs.perform_async({:key_id => self.id})  if s3_update
  end

  def push_to_resque_destroy
    Notes::NoteBodyJobs.perform_async({:key_id => self.id, :delete => true})  if s3_delete
  end

  def create_in_s3
    self.s3_create = true 
  end

  def update_in_s3
    self.s3_update = true
  end

  def delete_in_s3
    self.s3_delete = true
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

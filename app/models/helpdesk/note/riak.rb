# This module is an extension for Helpdesk::Note
# This module is a wrapper between riak and mysql

class Helpdesk::Note < ActiveRecord::Base
  # creating a key, value pair in riak
  def create_in_riak
    begin
      puts "creating a riak entry for node"
      set_associations_note_id_account_id
      self.note_body_content.reset_attribute_changed
      key = "#{self.account_id}/#{self.id}"
      value = self.note_body_content.to_json
      Helpdesk::Riak::Note::Body.store_in_riak(key,value)
    rescue Exception => e
      # push into redis
      $redis_tickets.perform_redis_op("rpush", Redis::RedisKeys::RIAK_FAILED_NOTE_CREATION,"#{self.account_id}/#{self.id}")
      NewRelic::Agent.notice_error(e,{:description => "error occured while saving note into riak"})
    end
  end

  # fetching from riak
  def read_from_riak
    data = Helpdesk::Riak::Note::Body.get_from_riak("#{self.account_id}/#{self.id}")
    riak_note_body = Helpdesk::NoteBody.new(data["note_body"])
    riak_note_body.new_record = false
    riak_note_body.reset_attribute_changed
    self.previous_value = riak_note_body.clone
    return riak_note_body
  end


  # update and create would be calling create_in_riak
  alias_method :update_in_riak, :create_in_riak
  alias_method :rollback_in_riak, :create_in_riak

  # deleting a key in riak
  def delete_in_riak
    begin
      $note_body.delete("#{account_id}/#{self.id}")
    rescue Exception => e
      $redis_tickets.perform_redis_op("rpush", Redis::RedisKeys::RIAK_FAILED_NOTE_DELETION,"#{self.account_id}/#{self.id}")
      NewRelic::Agent.notice_error(e,{:description => "error occured while deleting note from riak"})
    end
  end

  def set_associations_note_id_account_id
    self.note_body_content.account_id = self.account_id
    self.note_body_content.note_id = self.id
  end
end

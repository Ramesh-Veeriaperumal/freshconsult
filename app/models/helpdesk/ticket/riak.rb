# This module is an extension for Helpdesk::Ticket
# This module is a wrapper between riak and mysql

class Helpdesk::Ticket < ActiveRecord::Base
  # creation of key,value pair in riak
  def create_in_riak
    begin
      puts "creating a riak entry for #{self.account_id}/#{self.id}"
      set_associations_ticket_id_account_id
      self.ticket_body_content.reset_attribute_changed
      key = "#{self.account_id}/#{self.id}"
      value = self.ticket_body_content.to_json
      Helpdesk::Riak::Ticket::Body.store_in_riak(key,value)
    rescue Exception => e
      # push into redis incase where the saving of ticket is failed in riak
      $redis_tickets.perform_redis_op("rpush", Redis::RedisKeys::RIAK_FAILED_TICKET_CREATION,"#{self.account_id}/#{self.id}")
      NewRelic::Agent.notice_error(e,{:description => "error occured while saving ticket into riak"})
    end
  end

  # fetching data from riak
  def read_from_riak
    data = Helpdesk::Riak::Ticket::Body.get_from_riak("#{self.account_id}/#{self.id}")
    riak_ticket_body = Helpdesk::TicketBody.new(data["ticket_body"])
    riak_ticket_body.new_record = false
    riak_ticket_body.reset_attribute_changed
    self.previous_value = riak_ticket_body.clone
    return riak_ticket_body
  end

  # update and rollback in riak calls the same create function
  alias_method :update_in_riak, :create_in_riak
  alias_method :rollback_in_riak, :create_in_riak

  # deletion of key from riak
  def delete_in_riak
    begin
      # removing from riak
      $ticket_body.delete("#{self.account_id}/#{self.id}")
    rescue Exception => e
      # pushing into redis incase where riak ticket deltion is failed 
      $redis_tickets.perform_redis_op("rpush", Redis::RedisKeys::RIAK_FAILED_TICKET_DELETION,"#{self.account_id}/#{self.id}")
      NewRelic::Agent.notice_error(e,{:description => "error occured while deleting ticket from riak"})
    end
  end

  def set_associations_ticket_id_account_id
    self.ticket_body_content.account_id = self.account_id
    self.ticket_body_content.ticket_id = self.id
  end

end

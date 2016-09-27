class Helpdesk::Ticket < ActiveRecord::Base

  #Dynamo constants
  TABLE_NAME = "helpkit_ticket"
  HASH_KEY = "ticket_account"
  ASSOCIATES = "associates"

  TicketConstants::TICKET_ASSOCIATION.each do |type|
    define_method("#{type[0]}_ticket?") do
      self.association_type && self.association_type == type[1]
    end
  end

  def linked_ticket?
    self.tracker_ticket? || self.related_ticket?
  end

  def tracker_ticket
    if self.related_ticket? && self.associates.present?
      account.tickets.find_by_display_id(self.associates.first)
    end
  end

  def related_tickets(options=[])
    account.tickets.preload(options).where(:display_id => self.associates) if self.tracker_ticket? && self.associates.present?
  end

  def can_be_linked?
    !(deleted || spam || parent_ticket.present?)
  end

  def related_tickets_count
    if tracker_ticket?
      associates.present? ? associates.count : 0
    end
  end

  def delete_broadcast_notes
    if self.tracker_ticket?
      self.notes.broadcast_notes.readonly(false).each { |note| note.update_attributes(:deleted => true) }
    else
      self.notes.where(:source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['tracker']).update_all(:deleted => true)
    end
  end

  def reset_associations
    if self.linked_ticket? 
      self.tracker_ticket? ? reset_tracker : reset_related
    end
  end

  def associates
      #get item
      @associates ||= begin
        hash =  {
         :key => HASH_KEY, 
         :value => "#{self.display_id}_#{self.account.id}"
        }
        resp = Helpdesk::Tickets::Dynamo::DynamoHelper.get_item(
                  TABLE_NAME, 
                  hash, 
                  nil, 
                  "#{HASH_KEY}, #{ASSOCIATES}",
                  true)
       resp_item?(resp) ? resp.data.item[ASSOCIATES].map {|e| e.to_i} : nil
      end
  end

  def associates=(val)
      @associates = nil
      #get item
      hash =  {
         :key => HASH_KEY, 
         :value => "#{self.display_id}_#{self.account.id}"
        }
      resp = Helpdesk::Tickets::Dynamo::DynamoHelper.put_item(
                TABLE_NAME, 
                hash, 
                nil, 
                {ASSOCIATES => val.to_set}) #dynamo needs the value to be in a set
     return resp.data.attributes[ASSOCIATES].map {|e| e.to_i} if resp_data?(resp)
     nil
  end

  def add_associates(val)
    update_associates(val,"ADD")
  end

  def remove_associates(val)
    update_associates(val,"DELETE")
  end

  def update_associates(val, action="ADD")
    @associates = nil
    hash =  {
     :key => HASH_KEY, 
     :value => "#{self.display_id}_#{self.account.id}"
    }
    resp = Helpdesk::Tickets::Dynamo::DynamoHelper.update_set_attributes(
                TABLE_NAME, 
                hash, nil,
                {ASSOCIATES => val}, action)
    return resp.data.attributes[ASSOCIATES].map {|e| e.to_i} if resp_data?(resp)
    nil
  end

  def remove_all_associates
    @associates = nil
    hash =  {
     :key => HASH_KEY, 
     :value => "#{self.display_id}_#{self.account.id}"
    }
    resp = Helpdesk::Tickets::Dynamo::DynamoHelper.delete_attributes(
                TABLE_NAME, 
                hash, nil,
                [ASSOCIATES])
    return resp.data.attributes[ASSOCIATES].map {|e| e.to_i} if resp_data?(resp)
    nil
  end

  def resp_data?(resp)
    resp and resp.data and resp.data.attributes and resp.data.attributes[ASSOCIATES]
  end

  def resp_item?(resp)
    resp and resp.data and resp.data.item and resp.data.item[ASSOCIATES]
  end


  private

    def reset_tracker
      self.related_tickets.each do |r|
        r.update_attributes(:association_type => nil, :associates_rdb => nil)
        r.remove_all_associates
        r.delete_broadcast_notes
      end
      if Account.current.features?(:activity_revamp)
        self.misc_changes = {:tracker_unlink_all => self.related_tickets_count}
        self.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY)
      end 
      remove_all_associates
      delete_broadcast_notes
    end

    def reset_related
      tracker = self.tracker_ticket
      tracker.remove_associates([self.display_id]) if tracker.present?
      self.update_attributes(:association_type => nil, :associates_rdb => nil)
      remove_all_associates
      create_tracker_activity(:tracker_unlink)
      delete_broadcast_notes
    end
end
class Helpdesk::Ticket < ActiveRecord::Base

  #Dynamo constants
  TABLE_NAME = "helpkit_ticket"
  HASH_KEY   = "ticket_account"
  ASSOCIATES = "associates"

  DEFAULT_TABLE_NAME = "helpkit_ticket_shard_default"
  TICKET_DYNAMO_NEXT_SHARD = "shard_1"

  TicketConstants::TICKET_ASSOCIATION.each do |type|
    define_method("#{type[0]}_ticket?") do
      self.association_type.present? && self.association_type == type[1]
    end
  end

  def linked_ticket?
    self.tracker_ticket? || self.related_ticket?
  end

  def assoc_parent_child_ticket?
    self.assoc_parent_ticket? || self.child_ticket?
  end

  def associated_prime_ticket type #prime => parent or tracker ticket
    return false unless ["child", "related"].include? type
    if self.send("#{type}_ticket?") and self.associates.present?
      account.tickets.find_by_display_id(self.associates.first)
    end
  end

  def associated_subsidiary_tickets(type, options=[]) #subsidiary => child or related tickets
    return false unless ["assoc_parent", "tracker"].include? type
    account.tickets.preload(options).where(:display_id => self.associates) if self.send("#{type}_ticket?") && self.associates.present?
  end

  def can_be_associated?
    !(deleted || spam || parent_ticket.present?)
  end

  def child_tkt_limit_reached?
    association_type.nil? || (assoc_parent_ticket?  && asstn_obj_count < TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)
  end

  def related_tickets_count
    asstn_obj_count if tracker_ticket?
  end

  def child_tkts_count
    asstn_obj_count if assoc_parent_ticket?
  end

  def validate_assoc_parent_tkt_status
    child_tkt_states = self.associated_subsidiary_tickets("assoc_parent").pluck(:status)
    child_tkt_states.present? and (child_tkt_states - [CLOSED, RESOLVED]).present?
  end

  def delete_broadcast_notes
    self.notes.broadcast_notes.destroy_all if self.tracker_ticket?
  end

  def reset_associations
    if tracker_ticket?
      reset_tracker
    elsif related_ticket?
      reset_related
    elsif assoc_parent_ticket?
      reset_assoc_parent
    elsif child_ticket?
      reset_child
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
                  table_name,
                  hash,
                  nil,
                  "#{HASH_KEY}, #{ASSOCIATES}",
                  true)
       resp_item?(resp) ? resp.data.item[ASSOCIATES].map {|e| e.to_i} : nil
      end
  end

  def associates=(val)
      @associates = nil
      #put item
      hash =  {
         :key => HASH_KEY,
         :value => "#{self.display_id}_#{self.account.id}"
        }
      resp = Helpdesk::Tickets::Dynamo::DynamoHelper.put_item(
                table_name,
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
                table_name,
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
                table_name,
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

  def last_broadcast_message
    if self.related_ticket?
      Account.current.broadcast_messages.where(:tracker_display_id => associates.first).last
    end
  end

  private

    def table_name
      return @table_name if @table_name
      settings = self.account.account_additional_settings_from_cache.additional_settings
      @table_name = (settings.present? and settings[:tkt_dynamo_shard].present?) ?
                                "#{TABLE_NAME}_#{settings[:tkt_dynamo_shard]}" : DEFAULT_TABLE_NAME
    end

    def reset_tracker
      remove_prime_associates("tracker")
      if Account.current.features?(:activity_revamp) and (self.related_tickets_count > 0)
        self.misc_changes = {:tracker_unlink_all => self.related_tickets_count}
        self.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY)
      end
      remove_all_associates
      delete_broadcast_notes
    end

    def reset_related
      remove_subsidiary_associates("related")
    end

    def reset_assoc_parent
      remove_prime_associates("assoc_parent")
      nullify_assoc_type
      remove_all_associates
    end

    def reset_child
      @assoc_parent_ticket = self.associated_prime_ticket("child") #for activities
      remove_subsidiary_associates("child", @assoc_parent_ticket)
    end

    def remove_prime_associates type
      self.associated_subsidiary_tickets(type).each do |r|
        nullify_assoc_type(r)
        r.remove_all_associates
      end
    end

    def remove_subsidiary_associates type, prime_tkt = nil
      @prime_tkt = prime_tkt ? prime_tkt : self.associated_prime_ticket(type)
      nullify_assoc_type
      remove_all_associates
      prime_tkt_activity type if @prime_tkt.present?
    end

    def prime_tkt_activity type
      case type
      when "child"
        @prime_tkt.associates.count > 1 ? (@create_activity = :assoc_parent_tkt_unlink) : nullify_assoc_type(@prime_tkt)
      when "related"
        @create_activity = :tracker_unlink
      end
      create_assoc_tkt_activity(@create_activity, @prime_tkt, self.display_id) if @create_activity.present?
      @prime_tkt.remove_associates([self.display_id])
    end

    def nullify_assoc_type item = self
      item.update_attributes(:association_type => nil, :associates_rdb => nil)
    end

    def asstn_obj_count
      @asstn_obj_count ||= associates.present? ? associates.count : 0
    end
end
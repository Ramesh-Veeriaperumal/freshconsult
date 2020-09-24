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

  alias_method :is_parent, :assoc_parent_ticket? #for mobile

  def linked_ticket?
    self.tracker_ticket? || self.related_ticket?
  end

  def assoc_parent_child_ticket?
    self.assoc_parent_ticket? || self.child_ticket?
  end

  def prime_ticket?
    self.tracker_ticket? || self.assoc_parent_ticket?
  end

  def associated_ticket?
    self.association_type.present? && TICKET_ASSOCIATION_TOKEN_BY_KEY.key?(self.association_type)
  end

  def associated_prime_ticket type #prime => parent or tracker ticket
    return false unless ["child", "related"].include? type
    if self.safe_send("#{type}_ticket?") and self.associates.present?
      account.tickets.find_by_display_id(self.associates.first)
    end
  end

  def associated_subsidiary_tickets(type, options=[]) #subsidiary => child or related tickets
    return false unless ["assoc_parent", "tracker"].include? type
    account.tickets.preload(options).where(:display_id => self.associates) if self.safe_send("#{type}_ticket?") && self.associates.present?
  end

  def can_be_associated?
    !(deleted || spam || parent_ticket.present?)
  end

  def cannot_add_child?
    association_type.present? && !assoc_parent_ticket?
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

  # count from dynamo(Related & Child tickets count)
  def associated_tickets_count
    prime_ticket? ? asstn_obj_count : 0
  end

  def associated_ticket_count
    return 0 if association_type.nil?
    prime_ticket? ?
      asstn_obj_count :
      associated_prime_ticket(TicketConstants::TICKET_ASSOCIATION_FILTER_NAMES_BY_KEY[association_type.to_s]).safe_send('asstn_obj_count')
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
        if Account.current.launched?(:get_associates_from_db)
          associates_from_db
        else
          hash = {
            :key => HASH_KEY,
            :value => "#{self.display_id}_#{self.account.id}"
          }
          resp = Helpdesk::Tickets::Dynamo::DynamoHelper.get_item(
            table_name,
            hash,
            nil,
            "#{HASH_KEY}, #{ASSOCIATES}",
            true
          )
          resp_item?(resp) ? resp.data.item[ASSOCIATES].map { |e| e.to_i } : associates_from_db
        end
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
    update_associates(val, Dynamo::DYNAMO_ACTIONS[:add])
  end

  def remove_associates(val)
    update_associates(val,"DELETE")
  end

  def update_associates(val, action = Dynamo::DYNAMO_ACTIONS[:add])
    @associates = nil
    hash =  {
     :key => HASH_KEY,
     :value => "#{self.display_id}_#{self.account.id}"
    }
    resp = Helpdesk::Tickets::Dynamo::DynamoHelper.update_set_attributes(
                table_name,
                hash, nil,
                { ASSOCIATES => val}, action)
    update_associates_count(self) if action == Dynamo::DYNAMO_ACTIONS[:add]
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

  def associates_from_db
    if self.prime_ticket?
      associated_tickets = Sharding.run_on_slave {
        Account.current.tickets.where(:associates_rdb => self.display_id).pluck(:display_id) }
      update_associates_count(self, associated_tickets.count) if associated_tickets.present?
    elsif self.related_ticket? || self.child_ticket?
      associated_tickets = [self.associates_rdb]
    end
    notify_associates_fallback(associated_tickets) if associated_tickets.present?
    self.associates = associated_tickets
  rescue => e
    Rails.logger.info "Error associates_from_db #{e} - #{Account.current.id} - ticket #{self.display_id}"
  ensure
    return associated_tickets
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

  def schema_less_ticket_updated?
    self.schema_less_ticket.changed?
  end

  def custom_fields_updated?
    self.flexifield.before_save_changes.present?
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
      if self.related_tickets_count > 0
        self.misc_changes = {:tracker_unlink_all => self.related_tickets_count}
        self.manual_publish(["update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY], [:update, { misc_changes: self.misc_changes.dup }])
      end
      nullify_tracker_associates
    end

    def reset_related
      remove_subsidiary_associates("related")
    end

    def reset_assoc_parent
      subsidiary_tickets = self.associated_subsidiary_tickets('assoc_parent')

      # Service task logic.
      service_task_type = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
      service_task_present = subsidiary_tickets.any? { |t| t.ticket_type == service_task_type }
      subsidiary_tickets.reject! { |t| t.ticket_type == service_task_type } if service_task_present

      remove_prime_associates('assoc_parent', subsidiary_tickets)

      if service_task_present
        # If everything in subsidiary_tickets is a service task, subsidiary_tickets will be []. No need to perform the next operations(Only parent-child has to be removed).
        return if subsidiary_tickets.blank?

        # Instead of destroying the parent key via remove_all_associates: remove only the normal child ticket IDs in dynamo.
        ids_to_remove = subsidiary_tickets.map(&:display_id)
        update_associates(ids_to_remove, 'DELETE')

        # Updating count to service tasks count after removing normal child tickets.
        update_associates_count(self)
        self.misc_changes = { association_parent_unlink_all: ids_to_remove }
      else
        self.misc_changes = { association_parent_unlink_all: self.associates }
        nullify_assoc_type
        remove_all_associates
      end
      self.manual_publish(nil, [:update, { misc_changes: self.misc_changes.dup }]) if self.misc_changes.present?
    end

    def reset_child
      @assoc_parent_ticket = self.associated_prime_ticket("child") #for activities
      remove_subsidiary_associates("child", @assoc_parent_ticket)
    end

    def remove_prime_associates(type, subsidiary_tickets = nil)
      (subsidiary_tickets || self.associated_subsidiary_tickets(type)).each do |r|
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
      @prime_tkt.remove_associates([self.display_id])
      case type
      when "child"
        asstn_obj_count(@prime_tkt).zero? ? nullify_assoc_type(@prime_tkt) : (@create_activity = :assoc_parent_tkt_unlink)
      when "related"
        @create_activity = :tracker_unlink
      end
      if @create_activity.present?
        create_assoc_tkt_activity(@create_activity, @prime_tkt, self.display_id)
        update_associates_count(@prime_tkt)
      end
    end

    def nullify_assoc_type item = self
      update_hash = { :association_type => nil, :associates_rdb => nil }
      item.schema_less_ticket.additional_info.delete(:subsidiary_tkts_count) if item.prime_ticket?
      item.update_attributes(update_hash)
    end

    def asstn_obj_count item = self # count from dynamo
      item.associates.present? ? item.associates.count : 0
    end

    def nullify_tracker_associates
      remove_all_associates
      update_hash = if self[:link_feature_disable]
        self.schema_less_ticket.additional_info.delete(:subsidiary_tkts_count)
        { :association_type => nil }
      else
        { :subsidiary_tkts_count => self.related_tickets_count }
      end
      self.update_attributes(update_hash)
      delete_broadcast_notes
    end

    def notify_associates_fallback(associated_tickets)
      topic = SNS["associated_tickets_fallback_topic"]
      subj = "Associated tickets dynamo fallback"
      message = "Account id: #{self.account_id} \n Ticket id: #{self.display_id} \n Associated tickets id : #{associated_tickets.inspect} \n Time: #{Time.now.utc}"
      DevNotification.publish(topic, subj, message.to_json)
    end
end

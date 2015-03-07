class Helpdesk::Ticket < ActiveRecord::Base

  def push_to_resque_create
    # value = construct_ticket_old_body_hash.merge(add_created_at_and_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_ticket_bodies")
    # Heldpesk::TicketBodyWeekly.create(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Ticket::TicketBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     :create => true,
                     :requester_id => self.requester_id
                     # :table_name => table_name
    }) if s3_create
  end

  def read_from_s3
    object= Helpdesk::S3::Ticket::Body.get_from_s3(self.account_id,self.id)
    s3_ticket_body = Helpdesk::TicketBody.new(object)
    s3_ticket_body.new_record = false
    s3_ticket_body.reset_attribute_changed
    self.previous_value = s3_ticket_body.clone
    return s3_ticket_body
  end

  def push_to_resque_update
    # value = construct_ticket_old_body_hash.merge(add_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_ticket_bodies")
    # value[:conditions] = {:account_id => self.account_id, :ticket_id => self.id}
    # Heldpesk::TicketBodyWeekly.create_or_update(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Ticket::UpdateTicketBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     # :table_name => table_name
    }) if s3_update
  end

  def push_to_resque_destroy
    Resque.enqueue(::Workers::Helpkit::Ticket::TicketBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     :delete => true
    }) if s3_delete
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

class Helpdesk::Ticket < ActiveRecord::Base

  def create_in_s3
    # value = construct_ticket_old_body_hash.merge(add_created_at_and_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_ticket_bodies")
    # Heldpesk::TicketBodyWeekly.create(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Ticket::TicketBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id,
                     :create => true
                     # :table_name => table_name
    })
  end

  def read_from_s3
    object= Helpdesk::S3::Ticket::Body.get_from_s3(self.account_id,self.id)
    s3_ticket_body = Helpdesk::TicketBody.new(object)
    s3_ticket_body.new_record = false
    s3_ticket_body.reset_attribute_changed
    self.previous_value = s3_ticket_body.clone
    return s3_ticket_body
  end

  def update_in_s3
    # value = construct_ticket_old_body_hash.merge(add_updated_at)
    # table_name = Helpdesk::Mysql::Util.table_name_extension("helpdesk_ticket_bodies")
    # value[:conditions] = {:account_id => self.account_id, :ticket_id => self.id}
    # Heldpesk::TicketBodyWeekly.create_or_update(table_name,value)
    Resque.enqueue(::Workers::Helpkit::Ticket::UpdateTicketBodyJobs, {
                     :account_id => self.account_id,
                     :key_id => self.id
                     # :table_name => table_name
    })
  end

  def delete_in_s3
    Resque.enqueue(::Workers::Helpkit::Ticket::TicketBodyJobs, {
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

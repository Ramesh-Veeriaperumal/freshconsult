class Helpdesk::TicketStatus < ActiveRecord::Base
  
  include Helpdesk::Ticketfields::TicketStatus
  
  set_table_name "helpdesk_ticket_statuses"

  belongs_to_account
  
  validates_length_of :name, :in => 1..25
  validates_uniqueness_of :name, :scope => :account_id, :message => I18n.t('status_name_validate_uniqueness_msg'), :case_sensitive => false
  validates_uniqueness_of :customer_display_name, :scope => :account_id, :message => I18n.t('status_cust_disp_name_uniqueness_msg'), :case_sensitive => false
  
  attr_protected :account_id, :status_id
  
  belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'
  
  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key => "status", :primary_key => "status_id",
           :conditions => 'helpdesk_tickets.account_id = #{account_id}'
           
  after_update :update_tickets_sla_on_status_change
  
  named_scope :visible, :conditions => {:deleted => false}
  
  def self.display_name(user=nil)
    user.try(:customer?) ? "customer_display_name" : "name"
  end

  def self.translate_status_name(status, user=nil)
      DEFAULT_STATUSES.include?(status.status_id) ? I18n.t("#{status.send(display_name(user)).downcase}") : status.send(display_name(user))
  end

  def self.choices(account)
    statuses = account.ticket_status_values
    statuses.map{|status| { :status_id => status.status_id, :name => status.name, :customer_display_name => status.customer_display_name, :stop_sla_timer => status.stop_sla_timer, :deleted => status.deleted } }
  end
  
  def self.statuses(account, user=nil)
    statuses = account.ticket_status_values
    statuses.map{|status| [translate_status_name(status,user), status.status_id]}
  end
  
  def self.status_keys_by_name(account, user=nil)
    Hash[*statuses(account,user).flatten].insensitive
  end
  
  def self.status_names_by_key(account, user=nil)
    statuses = account.ticket_status_values
    Hash[*statuses.map{|status| [status.status_id, translate_status_name(status,user)]}.flatten]
  end
  
  def self.donot_stop_sla_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => {:stop_sla_timer => false})
    statuses.collect { |status| status.status_id }
  end
  
  def self.onhold_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => ["stop_sla_timer = true
               and name not in ('Resolved','Closed')"])
    statuses.collect { |status| status.status_id }
  end
  
  def self.onhold_and_closed_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => {:stop_sla_timer => true})
    statuses.collect { |status| status.status_id }
  end
  
  def update_tickets_sla_on_status_change
    if stop_sla_timer_changed?
      send_later(:update_tickets_dueby)
    elsif deleted_changed?
      send_later(:update_tickets_sla)
    end
  end
  
  def active?
    !([RESOLVED, CLOSED].include?(status_id))
  end
  
  def open?
   (status_id == OPEN) #or (Helpdesk::TicketStatus.donot_stop_sla_statuses(account).include?(status_id))
  end
  
  def closed?
   (status_id == CLOSED)
  end
  
  def resolved?
   (status_id == RESOLVED)
  end
  
  def pending?
   (status_id == PENDING)
  end
 
 def onhold?
   Helpdesk::TicketStatus.onhold_statuses(account).include?(status_id)
 end
 
 def onhold_and_closed?
   Helpdesk::TicketStatus.onhold_and_closed_statuses(account).include?(status_id)
 end
  
    def update_tickets_sla
      tkt_states = tickets.visible.find(:all,
                      :joins => :ticket_states, 
                      :conditions => ['helpdesk_ticket_states.sla_timer_stopped_at IS ?', nil])
      tkt_states.each do |t_s|
        fetch_ticket = account.tickets.visible.find(t_s.id) 
        fetch_ticket.ticket_states.sla_timer_stopped_at ||= Time.zone.now #if(sla_stopped_at.nil?)
        fetch_ticket.ticket_states.save
      end
    end
  
    def update_tickets_dueby
      if stop_sla_timer?
        update_tickets_sla
      else
        tkt_states = tickets.visible.find(:all,
                        :joins => :ticket_states,
                        :conditions => ['helpdesk_ticket_states.sla_timer_stopped_at IS NOT NULL and due_by > helpdesk_ticket_states.sla_timer_stopped_at'])
        tkt_states.each do |t_s|
          begin
            fetch_ticket = account.tickets.visible.find(t_s.id)
            #fetch_ticket.cache_old_model
            fetch_ticket.set_dueby(true)
            fetch_ticket.send(:update_without_callbacks)
            fetch_ticket.ticket_states.sla_timer_stopped_at = nil
            fetch_ticket.ticket_states.save
          rescue Exception => e
            RAILS_DEFAULT_LOGGER.debug "Due by time update failed for Ticket ID : #{t_s.id} on status update"
            RAILS_DEFAULT_LOGGER.debug "Error message ::: #{e.message}"
          end
        end
      end
    end
end

# encoding: utf-8
class Helpdesk::TicketStatus < ActiveRecord::Base
  
  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::TicketStatus
  
  set_table_name "helpdesk_ticket_statuses"

  belongs_to_account
  
  validates_length_of :name, :in => 1..50 # changed from 25 to 50
  validates_presence_of :name, :message => I18n.t('status_name_validate_presence_msg')
  validates_uniqueness_of :name, :scope => :account_id, :message => I18n.t('status_name_validate_uniqueness_msg'), :case_sensitive => false
  
  attr_protected :account_id, :status_id
  
  belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'
  
  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key => "status", :primary_key => "status_id",
           :conditions => 'helpdesk_tickets.account_id = #{account_id}'
           
  after_update :update_tickets_sla_on_status_change

  after_commit_on_destroy :clear_statuses_cache
  after_commit_on_create :clear_statuses_cache
  after_commit_on_update :clear_statuses_cache
  
  named_scope :visible, :conditions => {:deleted => false}

  acts_as_list :scope => :account
  
  def self.display_name
    user = User.current
    user.try(:customer?) ? "customer_display_name" : "name"
  end

  def self.translate_status_name(status, disp_col_name=nil)
    st_name = disp_col_name.nil? ? status.send(display_name) : status.send(disp_col_name)
    DEFAULT_STATUSES.keys.include?(status.status_id) ? I18n.t("#{st_name.gsub(" ","_").downcase}", :default => "#{st_name}") : st_name
  end

  def self.statuses_list(account)
    statuses = account.ticket_status_values
    statuses.map{|status| { :status_id => status.status_id, :name => status.name, :customer_display_name => status.customer_display_name, :stop_sla_timer => status.stop_sla_timer, :deleted => status.deleted } }
  end
  
  def self.statuses(account)
    disp_col_name = self.display_name
    statuses = account.ticket_status_values
    statuses.map{|status| [translate_status_name(status, disp_col_name), status.status_id]}
  end
  
  def self.status_keys_by_name(account)
    Hash[*statuses_from_cache(account).flatten].insensitive
  end

  def self.status_names(account)
    disp_col_name = self.display_name
    statuses = account.ticket_status_values
    statuses.map{|status| [status.status_id, translate_status_name(status, disp_col_name)]}
  end
  
  def self.status_names_by_key(account)
    Hash[*status_names_from_cache(account).flatten]
  end
  
  def self.donot_stop_sla_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => {:stop_sla_timer => false})
    statuses.collect { |status| status.status_id }
  end
  
  def self.onhold_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => ["stop_sla_timer = true
               and status_id not in (?,?)", RESOLVED, CLOSED])
    statuses.collect { |status| status.status_id }
  end
  
  def self.onhold_and_closed_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => {:stop_sla_timer => true})
    statuses.collect { |status| status.status_id }
  end

  def self.unresolved_statuses(account)
    statuses = account.ticket_status_values.find(:all, :select => "status_id", :conditions => ["status_id not in (?,?)", RESOLVED, CLOSED])
    statuses.collect { |status| status.status_id }
  end
  
  def update_tickets_sla_on_status_change
    if deleted_changed?
      send_later(:update_tickets_sla)
    elsif stop_sla_timer_changed?
      send_later(:update_tickets_dueby)  
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
  alias :is_closed :closed?
  
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
   Helpdesk::TicketStatus.onhold_and_closed_statuses_from_cache(account).include?(status_id)
  end

    def update_tickets_sla
      tkt_states = tickets.visible
      tkt_states.each do |t_s|
        begin
          fetch_ticket = tickets.visible.find_by_id(t_s.id)
          next if(fetch_ticket.nil?)
          if (stop_sla_timer? or deleted?)
            fetch_ticket.ticket_states.sla_timer_stopped_at ||= Time.zone.now
          else
            fetch_ticket.ticket_states.sla_timer_stopped_at = nil
          end
          fetch_ticket.ticket_states.save
        rescue Exception => e
            NewRelic::Agent.notice_error(e)
            RAILS_DEFAULT_LOGGER.debug "SLA timer stopped at time update failed for Ticket ID : #{t_s.id} on status update"
            RAILS_DEFAULT_LOGGER.debug "Error message ::: #{e.message}"
        end
      end
    end
  
    def update_tickets_dueby
      if stop_sla_timer?
        update_tickets_sla
      else
        tkt_states = tickets.visible.find(:all,
                        :joins => :ticket_states,
                        :conditions => ['helpdesk_ticket_states.sla_timer_stopped_at IS NOT NULL'])
        tkt_states.each do |t_s|
          begin
            fetch_ticket = tickets.visible.find_by_id(t_s.id)
            next if(fetch_ticket.nil?)
            sla_timer_stopped_at_time = fetch_ticket.ticket_states.sla_timer_stopped_at
            if(!sla_timer_stopped_at_time.nil? and fetch_ticket.due_by > sla_timer_stopped_at_time)
              fetch_ticket.update_dueby(true)
              fetch_ticket.send(:update_without_callbacks)
            end
            fetch_ticket.ticket_states.sla_timer_stopped_at = nil
            fetch_ticket.ticket_states.save
          rescue Exception => e
            NewRelic::Agent.notice_error(e)
            RAILS_DEFAULT_LOGGER.debug "Due by time update failed for Ticket ID : #{t_s.id} on status update"
            RAILS_DEFAULT_LOGGER.debug "Error message ::: #{e.message}"
          end
        end
      end
    end

  class << self
    include Cache::Memcache::Helpdesk::TicketStatus
  end
end

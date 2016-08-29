# encoding: utf-8
class Helpdesk::TicketStatus < ActiveRecord::Base
  
  self.primary_key = :id
  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::TicketStatus
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  self.table_name =  "helpdesk_ticket_statuses"

  belongs_to_account
  
  validates_length_of :name, :in => 1..50 # changed from 25 to 50
  validates_presence_of :name, :message => I18n.t('status_name_validate_presence_msg')
  validates_uniqueness_of :name, :scope => :account_id, :message => I18n.t('status_name_validate_uniqueness_msg'), :case_sensitive => false

  attr_accessible :name, :customer_display_name, :stop_sla_timer, :deleted, :is_default, :ticket_field_id, :position
  belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key => "status", :primary_key => "status_id",
        :conditions => proc  { "helpdesk_tickets.account_id = #{send(:account_id)}" }

  has_many :archived_tickets, :class_name => 'Helpdesk::ArchiveTicket', :foreign_key => "status", :primary_key => "status_id",
      :conditions => proc  { "archive_tickets.account_id = #{send(:account_id)}" }

  after_update :update_tickets_sla_on_status_change_or_delete

  after_commit :clear_statuses_cache
  
  scope :visible, :conditions => {:deleted => false}

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
    statuses.map{|status| { :status_id => status.status_id, :name => Helpdesk::TicketStatus.translate_status_name(status,"name"), 
      :customer_display_name => Helpdesk::TicketStatus.translate_status_name(status,"customer_display_name"), 
      :stop_sla_timer => status.stop_sla_timer, :deleted => status.deleted } }
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
    status_ids = statuses_from_cache(account).map(&:last)
    status_ids.reject{|id| resolved_statuses.include?(id)}
  end

  def self.resolved_statuses
    [RESOLVED, CLOSED]
  end

  def update_tickets_sla_on_status_change_or_delete
    if deleted_changed?
      if redis_key_exists?(SLA_ON_STATUS_CHANGE)
        SlaOnStatusChange.perform_async({:status_id => self.id, :status_changed => false})
      else
        send_later(:update_tickets_sla)
      end
    elsif stop_sla_timer_changed?
      if redis_key_exists?(SLA_ON_STATUS_CHANGE)
        SlaOnStatusChange.perform_async({:status_id => self.id, :status_changed => true})
      else
        send_later(:update_tickets_sla_on_status_change)  
      end
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
    account.onhold_and_closed_statuses_from_cache.include?(status_id)
  end

  def update_sla_timer_stopped_at(ticket)
    Sharding.run_on_master do 
      begin
        if (stop_sla_timer? or deleted?)
          ticket.ticket_states.sla_timer_stopped_at ||= Time.zone.now
        else
          ticket.ticket_states.sla_timer_stopped_at = nil
        end
        ticket.ticket_states.save
      rescue Exception => e
          NewRelic::Agent.notice_error(e)
          Rails.logger.debug "SLA timer stopped at time update failed for Ticket ID : #{ticket.id} on status update"
          Rails.logger.debug "Error message ::: #{e.message}"
      end
    end
  end

  def update_ticket_due_by(ticket)
    Sharding.run_on_master do
      begin
        sla_timer_stopped_at_time = ticket.ticket_states.sla_timer_stopped_at
        if(!sla_timer_stopped_at_time.nil? and ticket.due_by > sla_timer_stopped_at_time)
          ticket.update_dueby(true)
          ticket.sneaky_save
        end
        ticket.ticket_states.sla_timer_stopped_at = nil
        ticket.ticket_states.save
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.debug "Due by time update failed for Ticket ID : #{ticket.id} on status update"
        Rails.logger.debug "Error message ::: #{e.message}"
      end
    end
  end

  def update_tickets_sla
    Sharding.run_on_slave do 
      tickets.preload(:ticket_states).visible.find_each(batch_size: 300) do |ticket|
        update_sla_timer_stopped_at(ticket)
      end
    end
  end

  def update_tickets_sla_on_status_change
    if stop_sla_timer?
      update_tickets_sla
    else
      Sharding.run_on_slave do 
        tickets.preload(:ticket_states).visible.joins(:ticket_states).where("helpdesk_ticket_states.sla_timer_stopped_at IS NOT NULL").find_each(batch_size: 300) do |ticket|
          update_ticket_due_by(ticket)
        end
      end
    end
  end

  class << self
    include Cache::Memcache::Helpdesk::TicketStatus
  end
end

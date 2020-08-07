# encoding: utf-8
class Helpdesk::Activity < ActiveRecord::Base
  self.table_name =  "helpdesk_activities"
  self.primary_key = :id
  
  belongs_to_account
  
  serialize :activity_data

  #belongs_to :account
  belongs_to :user
  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id, :user_id
  
  before_create :set_short_descr
  before_create :set_migration_key, :if => :feature_present?
  
  OLD_MIGRATION_KEYS = ["bi_reports", "bi_reports_1", "bi_reports_2"]
  MIGRATION_KEYS     = ["activities"]

  scope :freshest, ->(account){
    where(["helpdesk_activities.account_id = ? and notable_type != ?", account, "Helpdesk::ArchiveTicket"]).
    order('helpdesk_activities.id DESC')
  }

  scope :activity_since, ->(id) {
    where(["helpdesk_activities.id > ? and notable_type != ?", id,"Helpdesk::ArchiveTicket"]).
    order('helpdesk_activities.id DESC')
  }

  scope :archive_tickets_activity_before, ->(activity_id){
    where(["helpdesk_activities.id < ? and notable_type = ?", activity_id,"Helpdesk::ArchiveTicket"]).
    order('helpdesk_activities.id DESC')
  }

  scope :archive_tickets_activity_since, ->(id){
    where(["helpdesk_activities.id > ? and notable_type = ?", id , "Helpdesk::ArchiveTicket"]).
    order('helpdesk_activities.id DESC')
  }

  scope :activity_before, ->(activity_id){
    where(["helpdesk_activities.id < ? and notable_type != ?", activity_id,"Helpdesk::ArchiveTicket"]).
    order('helpdesk_activities.id DESC')
  }

  scope :only_tickets, ->{ where(["notable_type = ?", "Helpdesk::Ticket"]) }

  scope :status, ->(name) {
    where(["helpdesk_activities.activity_data like ?", "%status_name: #{name}%"]).
    select('DISTINCT helpdesk_activities.user_id').
    order('helpdesk_activities.id DESC').
    limit(1)
  }

  scope :include_modules, ->(notable) { where(notable_type: notable) }

  scope :newest_first, ->{ order("helpdesk_activities.id DESC") }

  scope :permissible , ->(user) {
    query = permissible_query_hash(user)
    where(query[:conditions]).joins(query[:joins])
  }

  def self.permissible_query_hash user
    query_hash = {}
    ticket_table, activity_table = Helpdesk::Ticket.table_name, Helpdesk::Activity.table_name 
    ticket_model = Helpdesk::Ticket.model_name

    if user.agent? and !user.all_tickets_permission?
      query_hash[:conditions] = Helpdesk::Ticket.permissible_condition(user)
      query_hash[:conditions][0] += " OR (#{activity_table}.notable_type != ?)"
      query_hash[:conditions] << ticket_model
    end

    query_hash[:joins] = "LEFT JOIN #{ticket_table} ON #{activity_table}.notable_id = #{ticket_table}.id AND #{activity_table}.account_id = #{ticket_table}.account_id AND notable_type = '#{ticket_model}'"
    query_hash
  end

  def ticket_activity_type
    #Getting the Activity type ( Eg: activities.tickets.status_change.long ) to just "status_change"
    description.chomp('.long').gsub('activities.tickets.','')
  end

  def activity_type
    description.split('.')[1]
  end

  def ticket?
    activity_type == 'tickets'
  end

  def note?
    ticket_activity_type.start_with?('conversation.')
  end

  def note
    return Helpdesk::Note.find(note_id) if note?
  end

  def note_id
    key = activity_data["eval_args"].keys.first
    return activity_data['eval_args'][key][1]['comment_id']
  end
  
  def activity_data_blank?
    activity_data.reject {|k,v| OLD_MIGRATION_KEYS.include?(k) }.blank?
  end

  def migrate_activity?
    activity_data["activities"].nil? and !description.include?("new_ticket") and !description.include?("new_outbound")
  end

  private
    def set_short_descr
      self.short_descr ||= description
    end
    
    def feature_present?
      # Added feature check as a separate method so that activities can reuse 
      # this by adding their feature
      true  # making it default for all accounts
    end
    
    def set_migration_key
      MIGRATION_KEYS.each do |key|
        self.activity_data.merge!(key => true)
      end
    end
    
end
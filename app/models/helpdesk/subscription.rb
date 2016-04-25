class Helpdesk::Subscription < ActiveRecord::Base
  self.table_name =  "helpdesk_subscriptions"
  self.primary_key = :id

  belongs_to_account
  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'

  belongs_to :user,
    :class_name => 'User'
    
  attr_protected :ticket_id, :account_id

  validates_uniqueness_of :ticket_id, :scope => :user_id
  validates_numericality_of :ticket_id, :user_id
  before_create :set_account_id

  # Added to handle sending data to count cluster
  after_commit :es_update_parent, :if => :es_count_enabled?
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  private
    def set_account_id
      self.account_id = ticket.account_id
    end

    def es_update_parent
      SearchSidekiq::TicketActions::DocumentAdd.perform_async({ 
                                                  :klass_name => 'Helpdesk::Ticket', 
                                                  :id => self.ticket_id,
                                                  :version_value => Search::Job.es_version
                                                })
    end

    def es_count_enabled?
      Account.current.launched?(:es_count_writes)
    end
end

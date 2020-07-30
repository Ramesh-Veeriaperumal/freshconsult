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
  before_destroy :save_deleted_subscription_info
  
  # Added to handle sending data to count cluster
  after_commit :es_update_parent, :if => :es_count_enabled?
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher
  include RepresentationHelper

  publishable on: [:create, :destroy], exchange_model: :ticket, exchange_action: :update

  def override_exchange_model(action)
    ticket.model_changes = [:create].include?(action) ? { watchers: { added: [user_id], removed: [] } } : { watchers: { added: [], removed: [@deleted_user_id] } }
  end

  def save_deleted_subscription_info
    @deleted_user_id = user_id
  end

  def self.central_publish_enabled?
    publish_event?
  end

  # When a system rule does add/remove watcher, the event will be published as a part of ticket update.
  # This method ensures that the event is published only when a user adds or removes a watcher,
  # thereby preventing duplicate events from being published in case of system rule execution.
  def self.publish_event?
    User.current && User.current.agent? && !Va::RuleActivityLogger.automation_execution?
  end

  private

    def set_account_id
      self.account_id = ticket.account_id
    end

    def to_rmq_json(keys,action)
      destroy_action?(action) ? watcher_identifiers : return_specific_keys(watcher_identifiers, keys)
    end

    def watcher_identifiers
      @rmq_watcher_identifiers ||= {
        "id"              =>  id,
        "user_id"         =>  user_id,
        "ticket_id"       =>  ticket_id,
        "account_id"      =>  account_id,
        "display_id"      =>  ticket.display_id
      }
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

class Bot::Response < ActiveRecord::Base
  self.table_name = 'bot_responses'
  self.primary_key = :id

  attr_accessible :ticket_id, :suggested_articles, :query_id
  attr_protected :account_id

  attr_accessor :model_changes, :useful_changed, :agent_feedback_changed

  belongs_to :account
  belongs_to :ticket, class_name: 'Helpdesk::Ticket'
  belongs_to :bot, polymorphic: true

  validates :ticket_id, uniqueness: true
  validates :query_id, uniqueness: true

  serialize :suggested_articles, Hash
  after_update :send_feedback_to_ml, :if => :ml_feedback_changes?
  after_commit :close_ticket, :if => Proc.new { useful_changed && changed_model_value }

  before_destroy :save_deleted_bot_response_info

  concerned_with :presenter
  publishable

  ARTICLE_ATTRIBUTES = [:useful, :opened, :agent_feedback]

  ARTICLE_ATTRIBUTES.each do |attr_name|
    define_method "assign_#{attr_name}" do |article_meta_id, value|
      return false if suggested_articles[article_meta_id][attr_name].eql? (value)
      # Currently model_changes datatype is hash as we update one attr/request
      self.model_changes = construct_model_changes(article_meta_id, attr_name.to_s, [suggested_articles[article_meta_id][attr_name], value])
      suggested_articles[article_meta_id][attr_name] = value
      assign_attributes({"#{attr_name}_changed".to_sym => true }) if respond_to?("#{attr_name}_changed".to_sym)
      return true
    end

    define_method "#{attr_name}?" do |article_meta_id|
      suggested_articles[article_meta_id][attr_name]
    end
  end

  def ml_feedback_changes?
    useful_changed || agent_feedback_changed
  end

  def close_ticket
    as_requester { 
      ticket.update_attribute(:status , Helpdesk::Ticketfields::TicketStatus::CLOSED)
    }
  end

  def as_requester
    user = ticket.requester
    user.make_current
    yield
  ensure
    User.reset_current_user
  end

  def solutions_without_feedback
    suggested_articles.each.map{ |k,v| k if v[:useful].nil? }.compact
  end

  def has_positive_feedback?
    suggested_articles.each { |k,v| return true if v[:useful] == true }
    return false
  end

  def save_deleted_bot_response_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def send_feedback_to_ml
    ::Bot::Emailbot::MlBotFeedback.perform_async(bot_response_id: id, article_meta_id: model_changes[:article_id])
  end

  def construct_model_changes id, key, model_change
    {
      article_id: id,
      key: key,
      value: model_change
    }
  end

  def changed_model_value
    model_changes[:value].last
  end
end

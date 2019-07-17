class Bot::Feedback < ActiveRecord::Base
  belongs_to :bot, polymorphic: true
  belongs_to_account
  has_one :feedback_mapping, class_name: 'Bot::FeedbackMapping', dependent: :destroy

  attr_accessible :bot_id, :category, :useful, :received_at, :query_id, :query, :external_info, :state, :suggested_articles

  validates :account_id, presence: true
  validates :bot_id, presence: true
  validates :received_at, presence: true
  validates :query_id, presence: true
  validates :query, presence: true
  validates :external_info, presence: true
  validates_inclusion_of :category, :in => BotFeedbackConstants::FEEDBACK_CATEGORY_TOKEN_BY_KEY.keys, :message=>I18n.t('not_supported')
  validates_inclusion_of :useful, :in => BotFeedbackConstants::FEEDBACK_USEFUL_TOKEN_BY_KEY.keys, :message=>I18n.t('not_supported')
  validates_inclusion_of :state, :in => BotFeedbackConstants::FEEDBACK_STATE_TOKEN_BY_KEY.keys, :message=>I18n.t('not_supported')

  serialize :external_info, Hash
  serialize :suggested_articles, Array

  def chat_id
    external_info[:chat_id]
  end

  def customer_id
    external_info[:customer_id]
  end

  def client_id
    external_info[:client_id]
  end

  def deleted!
    self.update_attributes(state: BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:deleted])
  end
end
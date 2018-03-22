class Bot::FeedbackMapping < ActiveRecord::Base

  belongs_to_account
  belongs_to :feedback, class_name: 'Bot::Feedback'
  has_one :bot, class_name: 'Bot', through: :feedback
  attr_accessible :feedback_id, :article_id, :account_id

  validates :account_id, presence: true
  validates :feedback_id, presence: true
  validates :article_id, presence: true

  concerned_with :presenter
  publishable on: :create

end

class Bot::FeedbackMapping < ActiveRecord::Base
  include RepresentationHelper
  
  acts_as_api

  api_accessible :central_publish do |b|
    b.add :article_id
    b.add proc { |x| x.feedback.query_id }, as: :question_id
    b.add proc { |x| x.feedback.query }, as: :question
    b.add proc { |x| x.feedback.bot.external_id }, as: :bot_external_id
  end

  def relationship_with_account
    :bot_feedback_mappings
  end

end

class Bot::Response < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |br|
    br.add :id
    br.add :ticket_id
    br.add :account_id
    br.add :bot_id
    br.add :suggested_hash, as: :suggested_articles
    br.add :query_id
    br.add proc { |x| x.bot.external_id }, as: :bot_external_id
    DATETIME_FIELDS.each do |key|
      br.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :ticket, template: :central_publish
  end

  api_accessible :central_publish_destroy do |br|
    br.add :id
    br.add :ticket_id
    br.add :account_id
  end

  def self.central_publish_enabled?
    Account.current.bot_email_central_publish_enabled?
  end

  def relationship_with_account
    :bot_responses
  end

  def suggested_hash
    articles = []
    suggested_articles.each do |article|
      articles.push(
        id: article.first,
        title: article.last[:title],
        opened: article.last[:opened],
        useful: article.last[:useful],
        agent_feedback: article.last[:agent_feedback]
      )
    end
    articles
  end

  def central_payload_type
    callback_action = [:create, :update, :destroy].find { |action| transaction_include_action? action }
    "bot_response_#{callback_action}" if callback_action.present?
  end

  def model_changes_for_central
    {
      suggested_articles: [
        {
          id: @model_changes[:article_id],
          attributes: [{
            name: @model_changes[:key],
            value: @model_changes[:value]
          }]
        }
      ]
    } if @model_changes
  end
end

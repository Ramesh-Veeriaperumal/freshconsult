class Tickets::BotResponseDecorator < ApiDecorator
  delegate :id, :ticket, :bot, :suggested_articles, :updated_at, to: :record

  def to_hash
    hash = {
      id: id,
      ticket_id: ticket.display_id,
      articles: bot_suggested_articles,
      updated_at: updated_at
    }
    [hash, bot_hash].inject(&:merge)
  end

  def bot_suggested_articles
    articles = []
    suggested_articles.each_pair do |article_id, value|
      articles << {
        id: article_id,
        title: value[:title],
        opened: value[:opened],
        useful: value[:useful],
        agent_feedback: value[:agent_feedback]
      }
    end
    articles
  end

  def bot_hash
    return {} if bot.blank?
    { bot_id: bot.id, bot: bot.profile }
  end
end
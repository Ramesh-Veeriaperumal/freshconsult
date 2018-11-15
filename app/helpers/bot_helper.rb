module BotHelper
  def bot_enabled?
    current_account.support_bot_enabled?
  end

  def portal_bot_enabled?
    bot_enabled? && current_bot && current_bot.render_widget_code?
  end

  def current_bot
    @current_bot ||= current_portal.bot
  end

  def feature_name
    FeatureConstants::BOT
  end

  def scoper
    current_account.bots
  end

  def bot_info(bot)
    "Bot training status:: #{bot.training_status}, Bot Id : #{bot.id}, Account Id : #{current_account.id}, Portal Id : #{bot.portal_id}, External Id : #{bot.external_id}" if bot
  end

  def validate_state(state)
    bot = @item || @bot
    if bot.training_status.to_i != state
      Rails.logger.error "Bot state error:: Action: #{action_name}, #{bot_info(bot)}"
      render_request_error(:invalid_bot_state, 409)
      return
    end
    true
  end

  def handle_exception
    yield
  rescue => error
    Rails.logger.error "Action name: #{action_name},Message: #{error.message}"
    logger.error error.backtrace.join("\n")
    render_base_error(:internal_error, 500)
  end

  def product_hash(portal)
    name = portal.main_portal? ? portal.name : portal.product.name
    {
      name: name,
      portal_id: portal.id,
      portal_logo: get_portal_logo_url(portal)
    }
  end

  def get_portal_logo_url(portal)
    logo = portal.logo
    logo_url = logo.content.url if logo.present?
    logo_url
  end

  def categories_list(portal)
    Language.for_current_account.make_current
    public_category_meta = portal.public_category_meta
    return [] unless public_category_meta
    articles_count = Solution::CategoryMeta.bot_articles_count_hash(public_category_meta.map(&:id))
    Language.reset_current
    public_category_meta.map do |category|
      { id: category.id, label: category.name, articles_count: articles_count[category.id] || 0 }
    end
  end
end

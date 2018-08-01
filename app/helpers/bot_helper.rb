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
end

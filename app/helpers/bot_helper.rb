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

end
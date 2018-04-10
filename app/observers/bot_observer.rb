class BotObserver < ActiveRecord::Observer

  observe Bot, Portal, Product

  def after_commit(item)
    if item.class.name == 'Bot' && create_or_destroy?(item)
      item.account.clear_bots_count_from_cache
    end
    item.account.clear_bots_from_cache if can_clear_bot_cache?(item)
  end

  private

  def create_or_destroy?(item)
    item.safe_send(:transaction_include_action?, :create) || item.safe_send(:transaction_include_action?, :destroy)
  end

  def can_clear_bot_cache?(item)
    !(item.safe_send(:transaction_include_action?, :destroy) && item.class.name == 'Bot')
  end
end


class Admin::BotDecorator < ApiDecorator
  include BotHelper

  delegate :id, :external_id, :portal, :enable_in_portal, :additional_settings, :category_ids, :training_status, :profile, :email_channel, to: :record

  def to_show_hash
    ret_hash = {
      product: product_hash(portal),
      id: id,
      external_id: external_id,
      enable_on_portal: enable_in_portal,
      all_categories: categories_list(portal),
      selected_category_ids: category_ids,
      widget_code_src: BOT_CONFIG[:widget_code_src],
      product_hash: BOT_CONFIG[:freshdesk_product_id],
      environment: BOT_CONFIG[:widget_code_env]
    }
    ret_hash[:analytics_mock_data] = true if additional_settings[:analytics_mock_data]
    ret_hash[:status] = training_status if training_status
    ret_hash.merge!(profile)
    ret_hash.merge!(email_channel_hash) if Account.current.bot_email_channel_enabled?
    ret_hash
  end

  def email_channel_hash
    value = email_channel
    {
      email_channel: value || false
    }
  end
end
class ChatWidget < ActiveRecord::Base
  include ChatHelper
  self.primary_key = :id
		belongs_to_account
		belongs_to :chat_setting
		belongs_to :business_calendar
		belongs_to :product
		before_destroy :destroy_widget

		attr_protected :account_id
		def destroy_widget
      if account.features?(:chat)
        chat_widget = product.chat_widget
        site_id = account.chat_setting.site_id
        if chat_widget && chat_widget.widget_id
          LivechatWorker.perform_async(
            {
              :worker_method => "delete_widget",
              :widget_id => chat_widget.widget_id,
              :siteId => site_id
            }
          )
        end
      end
    end
end
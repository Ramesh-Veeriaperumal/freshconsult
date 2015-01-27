class ChatWidget < ActiveRecord::Base
		belongs_to_account
		belongs_to :chat_setting
		belongs_to :business_calendar
		belongs_to :product
		before_destroy :destroy_widget

		attr_protected :account_id
		def destroy_widget
      if account.features?(:chat)
        site_id = chat_setting.display_id
        chat_widget = product.chat_widget
        if chat_widget && chat_widget.widget_id
          Resque.enqueue(Workers::Livechat, 
            {
              :worker_method => "destroy_widget", 
              :widget_id => chat_widget.widget_id, 
              :siteId => site_id
            }
          )
        end
      end
    end
end
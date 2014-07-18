class Notification::ProductNotificationController < ApplicationController
  include MemcacheKeys

  def index
    @cache_content = notifications_content
    render :layout => false
  end

  private
  def notifications_content
    MemcacheKeys.fetch(PRODUCT_NOTIFICATION) do
      render_to_string :partial => 'notification/product_notification', 
                       :object => SubscriptionAnnouncement.latest_product_notifications
    end
  end 
end

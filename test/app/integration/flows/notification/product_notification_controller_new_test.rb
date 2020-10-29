# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'

class Notification::ProductNotificationControllerFlowTest < ActionDispatch::IntegrationTest
  def test_check_success_response_for_product_notification
    SubscriptionAnnouncement.any_instance.stubs(:latest_product_notifications).returns([])
    get 'notification/product_notification', nil, @headers
    assert_empty assigns[:object]
    assert_response 200
  ensure
    SubscriptionAnnouncement.any_instance.unstub(:latest_product_notifications)
  end

  def test_if_product_notification_template_is_rendered
    get 'notification/product_notification', nil, @headers
    assert_template :_product_notification
    assert_template 'notification/product_notification/index'
  end

  def test_object_title_url_message
    subscription_announcement = SubscriptionAnnouncement.latest_product_notifications.create(title: 'Sample title', url: 'https://sample.com', message: 'sample message')
    get 'notification/product_notification', nil, @headers
    assert_equal assigns[:object].last.title, subscription_announcement.title
    assert_equal assigns[:object].last.url, subscription_announcement.url
    assert_equal assigns[:object].last.message, subscription_announcement.message
  ensure
    subscription_announcement.destroy
  end

  private

    def old_ui?
      true
    end
end

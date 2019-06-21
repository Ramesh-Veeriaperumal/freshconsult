require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class TicketActionsUtilTest < ActionView::TestCase
  include AccountHelper
  include Facebook
  include TicketActions
  include Util

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account = create_test_account
    @@before_all_run = true
  end

  def teardown
    super
  end

  def test_fetch_user_facebook_mapping_wrong_user_id
    User.first.make_current
    user = User.current
    user.fb_profile_id = 'abc'
    user.save
    params = { fb_page_id: 1, page_scope_id: 'xyz', app_scope_id: 'abc', user_id: User.last.id + 1 }
    fb_user_mapping = Account.current.fb_user_mappings.new(params)
    fb_user_mapping.save!
    resp = fetch_user_from_facebook_mapping('abc', 1)
    assert_equal resp, nil
  ensure
    TicketActionsUtilTest.any_instance.unstub(:fetch_page_scope_id)
  end
end

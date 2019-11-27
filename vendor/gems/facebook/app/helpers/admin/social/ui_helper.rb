module Admin::Social::UIHelper
  include Redis::Keys::Others
  include Redis::OthersRedis

  def list_fb_page_as_option_tag(object_name, method, options = {}, 
  	tag_checked_value = "1", advance_facebook_enabled)
    if advance_facebook_enabled
      check_box(object_name, method, options, tag_checked_value, nil)
    else
      radio_button(object_name, method, tag_checked_value, options)
    end
  end

  def euc_non_migrated_page?(account, page_id)
    return false unless account.launched?(:migrate_euc_pages_to_us)

    key = format(MIGRATE_EUC_FB_PAGES, account_id: account.id)
    ismember?(key, page_id)
  end
end
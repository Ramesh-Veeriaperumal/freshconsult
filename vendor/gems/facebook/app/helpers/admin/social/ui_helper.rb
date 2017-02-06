module Admin::Social::UIHelper

  def list_fb_page_as_option_tag(object_name, method, options = {}, 
  	tag_checked_value = "1", advance_facebook_enabled)
    if advance_facebook_enabled
      check_box(object_name, method, options, tag_checked_value, nil)
    else
      radio_button(object_name, method, tag_checked_value, options)
    end
  end
end
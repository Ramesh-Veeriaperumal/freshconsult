module Social::BaseHelper
  
  Social::Twitter::Constants::AVATAR_SIZES.each do |size|
    define_method("#{size}_twt_avatar") do |org_avatar_url|
      org_avatar_url[size]
    end
  end
  
  def blossom_or_blossom_classic?
    current_account.subscription.blossom? || current_account.subscription.blossom_classic?
  end
  
  def initial_call
    Social::Constants::STREAM_FEEDS_ACTION_KEYS[:index]
  end
  
  def show_old
    Social::Constants::STREAM_FEEDS_ACTION_KEYS[:show_old]
  end
  
  def fetch_new
    Social::Constants::STREAM_FEEDS_ACTION_KEYS[:fetch_new]
  end
  
  def handles_select_tag(current_handle)
    select_arr = "<select id='twt-as'>"
    @all_handles.each do |handle|
      select_arr << handle_options(handle, current_handle)
    end
    select_arr << '</select>'
    select_arr.html_safe
  end
  
  def handle_options(handle, select_handle)
    options = ""
    if handle.screen_name.eql?(select_handle.screen_name)  
      options << "<option value='#{handle.id}' selected='selected' data-img-url='#{@thumb_avatar_urls[handle.screen_name]}'>"
    else
      options << "<option value='#{handle.id}' data-img-url='#{@thumb_avatar_urls[handle.screen_name]}'>"
    end
    options << "#{handle.screen_name}" << '</option>'
  end
  
end
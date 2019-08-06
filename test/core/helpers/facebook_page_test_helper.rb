module FacebookPageTestHelper
  
  def sample_fb_page
    {
      'profile_id': rand(1_000_000_000),
      'access_token': SecureRandom.hex(15),
      'page_id': rand(10_000),
      'page_name': 'Enseble',
      'page_token': SecureRandom.hex(10),
      'page_img_url': 'https://scontent.xx.fbcdn.net/v/t1.0-1/p50x50/',
      'page_link': 'https://www.facebook.com/Enseble-2182948948623128/',
      'fetch_since': 0,
      'reauth_required': false,
      'source': 'localhost, localhost-facebook',
      'last_error': nil,
      'message_since': 1_554_125_122,
      'enable_page': true,
      'realtime_messaging': 0
    }
  end

  def central_payload(fb_page)
    {
                     id: fb_page.id,
             account_id: fb_page.account_id,
              page_name: fb_page.page_name,
        reauth_required: fb_page.reauth_required,
     realtime_messaging: fb_page.realtime_messaging,
           access_token: fb_page.encrypt_for_central(fb_page.access_token, 'facebook'),
             page_token: fb_page.encrypt_for_central(fb_page.page_token, 'facebook'),
    encryption_key_name: fb_page.encryption_key_name('facebook'),
             profile_id: fb_page.profile_id.to_s,
                page_id: fb_page.page_id.to_s,
             created_at: fb_page.utc_format(fb_page.created_at),
             updated_at: fb_page.utc_format(fb_page.updated_at)
    }
  end
end
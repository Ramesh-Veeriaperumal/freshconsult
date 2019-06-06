module FacebookTestHelper
  def sample_fb_page
    [
      {
        'profile_id': '113929453075050',
        'access_token': 'test-token7',
        'page_id': 2,
        'page_name': 'Enseble',
        'page_token': 'page-test-token7',
        'page_img_url': 'https://scontent.xx.fbcdn.net/v/t1.0-1/p50x50/',
        'page_link': 'https://www.facebook.com/Enseble-2182948948623128/',
        'fetch_since': 0,
        'reauth_required': false,
        'source': 'localhost, localhost-facebook',
        'last_error': nil,
        'message_since': 1554125122,
        'enable_page': true,
        'realtime_messaging': 0
      }
    ]
  end

  def sample_gateway_page_detail
    {
      'pages': [
        {
          'createdAt': '2019-04-05T06:43:58.122Z',
          'updatedAt': '2019-04-05T06:43:58.122Z',
          'id': 65,
          'freshdeskAccountId': '6',
          'facebookPageId': '725',
          'pod': '1',
          'region': 'us-east-1'
        }
      ],
      'meta': {
        'count': 1
      }
    }
  end

  def sample_callback_url
    'https://afakeapitest.com'
  end
end

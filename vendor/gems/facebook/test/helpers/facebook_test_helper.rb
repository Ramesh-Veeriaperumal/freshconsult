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

  def optimal_rule_params(stream_id, ticket_rule_id)
    {
      social_ticket_rule: [
        {
          ticket_rule_id: ticket_rule_id,
          rule_type: 2,
          import_visitor_posts: true,
          import_company_comments: true,
          includes: [],
          group_id: '...'
        }
      ],
      new_ticket_filter_mentions: true,
      id: stream_id,
      visible_to: [0],
      primary_toggle: {
        switch: 0
      }
    }
  end

  def broad_rule_params(stream_id, ticket_rule_id)
    {
      social_ticket_rule: [
        {
          ticket_rule_id: ticket_rule_id,
          rule_type: 3,
          import_visitor_posts: true,
          import_company_comments: true,
          includes: [],
          group_id: '...'
        }
      ],
      same_ticket_filter_mentions: true,
      id: stream_id,
      visible_to: [0],
      primary_toggle: {
        switch: 0
      }
    }
  end

  def ad_posts_params
    {
      ad_posts_filter_mentions: true,
      ad_posts: {
        group_id: '...',
        import_ad_posts: true
      },
      social_facebook_page: {}
    }
  end
end

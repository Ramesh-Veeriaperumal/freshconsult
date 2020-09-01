module EmailRateLimitTestHelper
  include Redis::Keys::RateLimit
  def get_email_rate_limit_payload(time)
    {
      data: {
        account_id: @account.id,
        payload_type: 'RATELIMITED',
        payload: {
          orgId: 'NO_ORG',
          accountId: '1',
          accountName: 'centralpush.example.com',
          product: 'FRESHDESK_EMAIL',
          path: '/email_service',
          rateLimitUsed: 2,
          retryAfter: 60,
          method: 'GET'
        }
      },
      meta: {
        central: {
          request_id: '155412b8-00cc-4171-954c-2b34fe6e893b',
          collected_at: time * 1000
        }
      }
    }
  end

  def fluffy_email_path_limit
    {
      "limit": 200,
      "granularity": :minute,
      "account_paths": [
        {
          "method": 'GET',
          "path": '/email_service',
          "limit": 100,
          "granularity": 'MINUTE'
        },
        {
          "method": 'GET',
          "path": '/email_service_spam',
          "limit": 100,
          "granularity": 'MINUTE'
        }
      ]
    }
  end

  def default_limit
    {
      "limit": 400,
      "granularity": :minute
    }
  end
end

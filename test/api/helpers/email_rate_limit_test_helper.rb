module EmailRateLimitTestHelper
  def get_email_rate_limit_payload
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
      }
    }
  end
end

module RateLimitTestHelper
  include Redis::Keys::RateLimit

  def fluffy_api_path_limit
    {
      "limit": 200,
      "granularity": :minute,
      "account_paths": [
        {
          "method": 'GET',
          "path": '/tickets',
          "limit": 100,
          "granularity": 'MINUTE'
        },
        {
          "method": 'GET',
          "path": '/contacts',
          "limit": 100,
          "granularity": 'MINUTE'
        },
        {
          "method": 'POST',
          "path": '/tickets',
          "limit": 100,
          "granularity": 'MINUTE'
        },
        {
          "method": 'PUT',
          "path": '/tickets',
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

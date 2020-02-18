module PciConstants
  ISSUER = 'freshdesk'.freeze
  OBJECT_TYPE = 'ticket'.freeze
  EXPIRY_DURATION = 2.minutes.freeze
  ACTION = {
    none: 0,
    read: 1,
    write: 2
  }.freeze

  class JweConstants
    # Adding the public key here for development purpose, will add it to the yml in next release
    PUBLIC_KEY = "-----BEGIN PUBLIC KEY-----\nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqRhRG3KhulKxSITOxyrv\nZC0bU0mx8XTXbdXqPLf+Zw4DzRt9qXrnbfkW9V6hc1e6DldLQPqr4MQ/mo8g66ir\nD7z8LkPxQ2Le1hStJOGf9Ai01n0itM55adEj345FLBF7m4iV0OX6YU/T9+xhOaN0\n50Y+BaoWNeIp5nBkZBHBk2jZgqQf2NG3ZoNBUYDLQouJl2S6RVLDRj/olsIXJmGF\nwao334U7Ky+x9JbHNneWRGuWPyiT2D/PEUZei6EOl1cq7w9C7L3aPn9Beo3zwb8i\nOtXN42+dyb8Zqmd5V0PEv4BtuhuPwjIUjcHRPhOQ3Bcdx2Rx6eWZm+0ki5LK86K1\nmD60f3Adrx02AVgw9mtUYH/krRWHsEDyLgGHcOeyQ7lT1tgu90wSNcM7gfLJwYsV\n1jEV0XwU+OR/vy1WhRhX1qbscxgcWNuElXwZWs6ws/UgtEydMgaaQZkfyOzXp97O\nL07MdlVQ8pPaOX+j/b/cC7tSgjo8sKRyd2gbLOtweD/HclbZXSvbnHqK/9D+UvvK\nUvR4MqNs8I6P7nMp3SgDOn6aYKT7nSu9eco182guJqtof4vaxE2sN3tR0u7pYLdJ\nlZEB87Zd7/31WpqYUybmRvIw6uC3gaF/CFW5R4cjPIfiRfB9E7Sl3oi+grGpFPzJ\njQQnOYIU6/cRtPRnqDrtoaUCAwEAAQ==\n-----END PUBLIC KEY-----\n".freeze
  end
end

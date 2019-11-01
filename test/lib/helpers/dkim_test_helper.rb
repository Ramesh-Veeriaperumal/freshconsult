module DkimTestHelper
  def email_service_response_hash
    {
      'result' => [{
        'accountId' => 1,
        'default' => false,
        'records' => {
          'dkim' => [
            {
              'host' => '2ryzss1._domainkey.test.com',
              'verified' => true,
              'type' => 'CNAME',
              'value' => 'wl122001s1.domainkey.freshpo.com'
            },
            {
              'host' => 'yoqz5s2._domainkey.test.com',
              'verified' => true,
              'type' => 'CNAME',
              'value' => 'wl122001s2.domainkey.freshpo.com'
            },
            {
              'host' => 'btnz1s3._domainkey.test.com',
              'verified' => true,
              'type' => 'CNAME',
              'value' => 'wl122001s3.domainkey.freshpo.com'
            }
          ],
          'spfmx' => {
            'host' => 'fwdkim.test.com',
            'verified' => true,
            'type' => 'CNAME',
            'value' => 'spfmx.domainkey.freshpo.com'
          }
        },
        'domain' => 'fresh.com',
        'subdomain' => 'fwdkim',
        'id' => 122_001
      }]
    }.to_json
  end

  def email_service_failure_hash
    {
      'Status' => 'Failure',
      'RequestId' => '5c4df889-6812-451d-9491-f71dfb7da52d',
      'errorMessage' => 'Something went wrong!',
      'action' => 'getAllWhitelabel'
    }.to_json
  end

  def make_email_config_active(email_config)
    email_config.active = true
    email_config.save!
    email_config.reload
  end

  def change_domain_status(domain, status)
    domain.status = status
    domain.last_verified_at = Time.now
    domain.save!
    domain.reload
  end
end

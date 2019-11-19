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

  def email_service_configure_hash
    {
      'accountId' => 1,
      'default' => false,
      'RequestId' => 'c72f59cc-be94-43cd-8bf5-a1ee796494ff',
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
    }.to_json
  end
  
  def email_service_verify_hash
    {
      'accountId' => 1,
      'default' => false,
      'RequestId' => 'c72f59cc-be94-43cd-8bf5-a1ee796494ff',
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
      'verified' => true,
      'id' => 122_001
    }.to_json
  end

  def sg_response_1
    [ 201, 
      {
        "id"=>3965684, 
        "user_id"=>4188027, 
        "subdomain"=>"fddkim", 
        "domain"=>"fresh.com", 
        "username"=>"default-user", 
        "ips"=>[], 
        "custom_spf"=>true, 
        "default"=>false, 
        "legacy"=>false, 
        "automatic_security"=>false, 
        "valid"=>false, 
        "dns"=> {
          "mail_server"=> {
            "valid"=>false, 
            "type"=>"mx", 
            "host"=>"fddkim.fresh.com", 
            "data"=>"mx.sendgrid.net."}, 
            "subdomain_spf"=> {
              "valid"=>false, 
              "type"=>"txt", 
              "host"=>"fddkim.fresh.com", 
              "data"=>"v=spf1 include:sendgrid.net ~all"
            }, 
            "dkim"=> {
              "valid"=>false, 
              "type"=>"txt", 
              "host"=>"fdm._domainkey.fresh.com", 
              "data"=>"k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDexHHIXtOS/Chy8tWttzHJ5Ss24gtrfY9ow/C2csLqKdHoJEQ/Ef72GZtBeP/5IlvEzuwugyNL4fmopumGjjFzPriRPZfzoJX6vjwCFTrxpqYZj9RiYqqsiPHbbl7zU/FHW2AWG4a50KWmYitdh7nrF+o+Uj343dlxSNzrcAcCuQIDAQAB"
            }
          }
        }
      ]
  end

  def sg_response_2
    [ 201, 
      {
        "id"=>3965685, 
        "user_id"=>4187556, 
        "subdomain"=>"fddkim", 
        "domain"=>"fresh.com", 
        "username"=>"free-user", 
        "ips"=>[], 
        "custom_spf"=>false, 
        "default"=>false, 
        "legacy"=>false, 
        "automatic_security"=>true, 
        "valid"=>false, 
        "dns"=> {
          "mail_cname" => {
            "valid"=>false, 
            "type"=>"cname", 
            "host"=>"fddkim.fresh.com", 
            "data"=>"u4187556.wl057.sendgrid.net"
          }, 
          "dkim1"=> { 
            "valid"=>false, 
            "type"=>"cname", 
            "host"=>"fd._domainkey.fresh.com", 
            "data"=>"fd.domainkey.u4187556.wl057.sendgrid.net"
          }, 
          "dkim2"=> {
            "valid"=>false, 
            "type"=>"cname", 
            "host"=>"fd2._domainkey.fresh.com", 
            "data"=>"fd2.domainkey.u4187556.wl057.sendgrid.net"
          }
        }
      }
    ]
  end
end

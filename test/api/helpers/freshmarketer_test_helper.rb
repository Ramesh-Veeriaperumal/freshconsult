module FreshmarketerTestHelper
  def stub_create_account
    stubs.post('/ab/api/v1/createsraccount') do |env|
      [200, {}, {
        status_code: 200,
        createsraccount: {
          account_id: '4759555256525C455C515442425C5F5D4C5E5C5F5F',
          authtoken: '1taehlg306k6bl88vpq44500970cmuuufnrq86br',
          cdnscript: "<script src=\'//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/48434356339/1300.js\'></script>",
          app_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/experiment/1406/session/sessions',
          integrate_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/settings/#/apikey'
        },
        resource_name: 'createsraccount'
      }.to_json]
    end
  end

  def stub_associate_account
    stubs.post('/ab/api/v1/associatesraccount') do |env|
      [200, {}, {
        status_code: 200,
        associatesraccount: {
          account_id: '4759555256525C455C515442425C5F5D4C5E5C5F5F',
          authtoken: '1taehlg306k6bl88vpq44500970cmuuufnrq86br',
          cdnscript: "<script src=\'//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/48434356339/1300.js\'></script>",
          app_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/experiment/1406/session/sessions',
          integrate_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/settings/#/apikey'
        },
        resource_name: 'createsraccount'
      }.to_json]
    end
  end

  def stub_enable_integration
    stubs.post('/ab/api/v1/sr/enableintegration') do |env|
      [200, {}, {
        status_code: 200,
        enableintegration: {
          result: "<script src=\'//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/48434356339/1300.js\'></script>"
        },
        resource_name: 'enableintegration'
      }.to_json]
    end
  end

  def stub_disable_integration
    stubs.post('/ab/api/v1/sr/disableintegration') do |env|
      [200, {}, {
        status_code: 200,
        resource_name: 'disableintegration',
        disableintegration: {
          result: true
        }
      }.to_json]
    end
  end

  def stub_cdn_script
    stubs.get('/ab/api/v1/sr/cdnscript') do |env|
      [200, {}, {
        status_code: '200',
        cdnscript: {
          result: "<script src=\'//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/48434356339/1300.js\'></script>"
        },
        resource_name: 'cdnscript'
      }.to_json]
    end
  end

  def stub_recent_sessions
    stubs.get('/ab/api/v1/sr/sessions') do |env|
      [200, {}, {
        status: '200',
        resource_name: 'sessions',
        sessions: [
          {
            id: '3433444455.333334',
            recorded_on: 1_526_901_796_479,
            duration: 101_005
          },
          {
            id: '3433444455.333334',
            recorded_on: 1_526_901_796_479,
            duration: 101_005
          }
        ]
      }.to_json]
    end
  end

  def stub_session
    stubs.get('/ab/api/v1/sr/session/3433444455.333334') do |env|
      [200, {}, {
        status: '200',
        resource_name: '{sessionid}',
        '{sessionid}': {
          result: 'http://localhost:8080/ab/share/bvadmqc17q0suhkhekjq0rjqk02ugron86kfpbj8'
        }
      }.to_json]
    end
  end

  def stub_experiment_details
    stubs.get('/ab/api/v1/sr/expdetails') do |env|
      [200, {}, {
        status_code: '200',
        expdetails: {
          experiment_name: 'FD integration for zappycub.com',
          last_modified_on: '1523535030766',
          experiment_url: 'zappycub.com',
          experiment_status: 'Paused',
          created_on: '1523534940222'
        },
        resource_name: 'expdetails'
      }.to_json]
    end
  end

  def stub_remove_account
    stubs.post('/ab/api/v1/sr/removeaccount') do |env|
      [200, {}, {
        Status: 'success'
      }.to_json]
    end
  end

  def stub_create_experiment
    stubs.post('/ab/api/v1/sr/create_experiment') do |env|
      [200, {}, {
        status_code: 200,
        create_experiment: {
          result: '4151515152505F435F415C51405F594C5C5A5F5F'
        },
        resource_name: 'create_experiment'
      }.to_json]
    end
  end

  def stub_enable_predictive_support
    stubs.put('/ab/api/v1/sr/enablepredictivesupport') do |env|
      [200, {}, {
        status_code: 200,
        enablepredictivesupport: {
          result: true
        },
        resource_name: 'enablepredictivesupport'
      }.to_json]
    end
  end

  def stub_disable_predictive_support
    stubs.put('/ab/api/v1/sr/disablepredictivesupport') do |env|
      [200, {}, {
        status_code: 200,
        disablepredictivesupport: {
          result: true
        },
        resource_name: 'disablepredictivesupport'
      }.to_json]
    end
  end

  def stub_create_experiment_error
    stubs.post('/ab/api/v1/sr/create_experiment') do |env|
      [500, {}, {
        status_code: 500,
        create_experiment: {
          result: false
        },
        resource_name: 'create_experiment'
      }.to_json]
    end
  end

  def stub_enable_predictive_support_error
    stubs.put('/ab/api/v1/sr/enablepredictivesupport') do |env|
      [500, {}, {
        status_code: 500,
        enablepredictivesupport: {
          result: false
        },
        resource_name: 'enablepredictivesupport'
      }.to_json]
    end
  end

  def stub_disable_predictive_support_error
    stubs.put('/ab/api/v1/sr/disablepredictivesupport') do |env|
      [500, {}, {
        status_code: 500,
        disablepredictivesupport: {
          result: false
        },
        resource_name: 'disablepredictivesupport'
      }.to_json]
    end
  end

  def stub_enable_integration_error
    stubs.post('/ab/api/v1/sr/enableintegration') do |env|
      [500, {}, {
        status_code: 500,
        enableintegration: {
          result: false
        },
        resource_name: 'enableintegration'
      }.to_json]
    end
  end

  def stub_disable_integration_error
    stubs.post('/ab/api/v1/sr/disableintegration') do |env|
      [500, {}, {
        status_code: 500,
        resource_name: 'disableintegration',
        disableintegration: {
          result: false
        }
      }.to_json]
    end
  end

  def stub_resource_conflict_error_response
    stubs.post('/ab/api/v1/createsraccount') do |env|
      [500, {}, {
        messagecode: 'E400EA',
        error: true,
        message: 'duplicate mail',
        status: 409
      }.to_json]
    end
  end

  def stub_forbidden_error_response
    stubs.post('/ab/api/v1/createsraccount') do |env|
      [500, {}, {
        messagecode: 'E409IC',
        error: true,
        message: 'invalid credentials',
        status: 403
      }.to_json]
    end
  end

  def stub_bad_request_error_response
    stubs.post('/ab/api/v1/createsraccount') do |env|
      [500, {}, {
        messagecode: 'E400IE',
        error: true,
        message: 'invalid email',
        status: 400
      }.to_json]
    end
  end

  def stub_internal_server_error_response
    stubs.post('/ab/api/v1/createsraccount') do |env|
      [500, {}, {
        messagecode: 'E400ISE',
        error: true,
        message: 'Something went wrong',
        status: 500
      }.to_json]
    end
  end

  def stub_connection
    faraday_stub = Faraday.new do |builder|
      builder.adapter :test, stubs
    end
    Freshmarketer::Client.any_instance.stubs(:freshmarketer_connection).returns(faraday_stub)
  end

  def unstub_connection
    Freshmarketer::Client.any_instance.unstub(:freshmarketer_connection)
  end

  def stubs
    @stubs ||= Faraday::Adapter::Test::Stubs.new
  end

  def save_freshmarketer_hash(fm_hash)
    account_additional_settings = Account.current.account_additional_settings
    account_additional_settings.additional_settings ||= {}
    account_additional_settings.additional_settings[:freshmarketer] = fm_hash
    account_additional_settings.save
  end

  def link_account_params
    email = "#{Faker::Internet.user_name}@#{@account.full_domain.partition('.').last}"
    { value: email, type: 'create' }
  end

  def linked_experiment_pattern(expected_output)
    [{
      linked: expected_output[:linked] || false,
      experiment: expected_output[:linked] ? { name: String, url: String, status: String, cdn_script: String, app_url: String, integrate_url: String } : {}
    }]
  end

  def session_pattern(session)
    {
      id: session[:id],
      recorded_on: session[:recorded_on],
      duration: session[:duration]
    }
  end

  def session_info_pattern
    {
      url: String
    }
  end
end

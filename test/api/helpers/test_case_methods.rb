module TestCaseMethods
  include Redis::RedisKeys
  def parse_response(response)
    JSON.parse(response)
  rescue
  end

  def skip_bullet
    original_value = Bullet.enable?
    Bullet.enable = false
    yield
  ensure
    Bullet.enable = original_value
  end

  def exceed_failed_login_count(value, rewind_updated_at = false)
    original_value = @agent.failed_login_count
    updated_at = @agent.updated_at
    new_updated_at = UserSession.failed_login_ban_for.seconds.ago - 1.minute
    @agent.update_attribute(:failed_login_count, value)
    @agent.update_column(:updated_at, new_updated_at) if rewind_updated_at
    yield original_value, value
  ensure
    @agent.update_attribute(:failed_login_count, original_value) if @agent.reload.failed_login_count == value
    @agent.update_column(:updated_at, updated_at) if rewind_updated_at && @agent.updated_at.to_s == new_updated_at
  end

  def set_password_expiry(value)
    @agent.update_attribute(:failed_login_count, 0)
    original_value = @agent.password_expiry
    @agent.set_password_expiry(password_expiry_date: value)
    yield
  ensure
    @agent.set_password_expiry(password_expiry_date: original_value)
  end

  def sidekiq_inline
    require 'sidekiq/testing'
    Sidekiq::Testing.fake!
    Sidekiq::Testing.inline! do
      yield
    end
  end

  def enable_adv_ticketing(features = [], &block)
    features.is_a?(Array) ? features.each { |f| add_feature(f) } : add_feature(features)
    if block_given?
      yield
      disable_adv_ticketing(features)
    end
  end

  def disable_adv_ticketing(features = [])
    Account.current.reload
    features.is_a?(Array) ? features.each { |f| remove_feature(f) } : remove_feature(features)
  end

  def add_feature(feature)
    if AccountSettings::SettingsConfig[feature.to_sym].present?
      Account.current.enable_setting(feature)
    else
      Account.current.add_feature(feature)
    end
  end

  def remove_feature(feature)
    if AccountSettings::SettingsConfig[feature.to_sym].present?
      Account.current.disable_setting(feature)
    else
      Account.current.revoke_feature(feature)
    end
  end

  def enable_public_api_filter_factory(features = [], &block)
    features.is_a?(Array) ? features.each { |f| enable_feature(f) } : enable_feature(features)
    yield if block_given?
  ensure
    disable_public_api_filter_factory(features)
  end

  def disable_public_api_filter_factory(features = [])
    features.is_a?(Array) ? features.each { |f| disable_feature(f) } : disable_feature(features)
  end

  # Temporary, till moved as settings
  def enable_feature(feature)
    Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(feature) ? Account.current.enable_setting(feature) : Account.current.launch(feature)
  end

  def disable_feature(feature)
    Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(feature) ? Account.current.disable_setting(feature) : Account.current.rollback(feature)
  end

  def stub_current_account
    Account.stubs(:current).returns(@account)
    yield
  ensure
    Account.unstub(:current)
  end

  def without_proper_fd_domain
    domain = DomainMapping.create(account_id: @account.id, domain: 'support.junk.com')
    original_value = host
    host!('support.junk.com')
    yield
  ensure
    host!(original_value)
    domain.destroy
  end

  def remove_wrap_params
    @old_wrap_params = @controller._wrapper_options
    @controller._wrapper_options = { format: [] }
  end

  def set_wrap_params
    @controller._wrapper_options = @old_wrap_params
  end

  def stub_const(parent, const, value, &_block)
    const = const.to_s
    old_value = parent.const_get(const)
    parent.const_set(const, value)
    yield
  ensure
    parent.const_set(const, old_value)
  end

  def request_params
    { version: 'v2', format: :json }
  end

  def match_json(json)
    if [400, 409].include?(response.status) && json.is_a?(Array)
      json = {
        description: ErrorConstants::ERROR_MESSAGES[:validation_failure],
        errors: json
      }
    end
    response.body.must_match_json_expression json
  end

  def match_custom_json(response, json)
    response.must_match_json_expression json
  end

  # pass params that are to be wrapped by controller name for 'wrapped'
  # and the rest like 'id' for 'unwrapped'
  def construct_params(unwrapped, wrapped = false)
    params_hash = request_params.merge(unwrapped)
    if wrapped
      wrapped_params = wrap_cname(wrapped)
      @request.env['RAW_POST_DATA'] = wrapped.to_json
      params_hash.merge!(wrapped_params)
    end
    params_hash
  end

  def controller_params(params = {}, query_string = true)
    remove_wrap_params

    # Stringifying the values as controller params are going to be used as query params in only GET & PUT request.
    params.each { |k, v| params[k] = v.is_a?(Array) ? v : v.to_s } if query_string
    request_params.merge(params)
  end

  def add_content_type
    @headers ||= {}
    @headers['CONTENT_TYPE'] = 'application/json'
  end

  def white_space
    ' ' * 300
  end

  def get_key(key)
    newrelic_begin_rescue { $rate_limit.get(key) }
  end

  def remove_key(key)
    newrelic_begin_rescue { $rate_limit.del(key) }
  end

  def set_key(key, value, expires = 86_400)
    newrelic_begin_rescue do
      $rate_limit.set(key, value)
      $rate_limit.expire(key, expires) if expires
    end
  end

  def api_key
    API_THROTTLER % { host: 'localhost.freshpo.com' }
  end

  def v2_api_key(account_id = @account.id)
    API_THROTTLER_V2 % { account_id: account_id }
  end

  def account_key
    ACCOUNT_API_LIMIT % { account_id: @account.id }
  end

  def default_key
    'DEFAULT_API_LIMIT'
  end

  def plan_key(id)
    PLAN_API_LIMIT % { plan_id: id.to_s }
  end

  EOL = "\015\012".freeze # "\r\n"
  # Encode params and image in multipart/form-data.
  def encode_multipart(params, image_param = nil, image_file_path = nil, content_type = nil, encoding = true)
    headers = {}
    parts = []
    boundary = '234092834029834092830498'
    params.each_pair do |key, val|
      if val.is_a? Hash
        val.each_pair do |child_key, child_value|
          parts.push %(Content-Disposition: form-data; ) + %(name="#{key}[#{child_key}]"#{EOL}#{EOL}#{child_value}#{EOL})
        end
      elsif val.is_a? Array
        val.each do |x|
          parts.push %(Content-Disposition: form-data; ) + %(name="#{key}[]"#{EOL}#{EOL}#{x}#{EOL})
        end
      else
        parts.push %(Content-Disposition: form-data; ) + %(name="#{key}"#{EOL}#{EOL}#{val}#{EOL})
      end
    end
    if image_param
      image_part = \
        %(Content-Disposition: form-data; name="#{image_param}"; ) + %(filename="#{File.basename(image_file_path)}"#{EOL}) + %(Content-Type: #{content_type}#{EOL}#{EOL})
      file_read_params = encoding ? [image_file_path, encoding: 'UTF-8'] : [image_file_path]
      image_part << File.read(*file_read_params) << EOL
      image_part = image_part.force_encoding('BINARY') if image_part.respond_to?(:force_encoding) && encoding
      parts.push(image_part)
    end
    body = parts.join("--#{boundary}#{EOL}")
    body = "--#{boundary}#{EOL}" + body + "--#{boundary}--" + EOL
    headers['CONTENT_TYPE'] = "multipart/form-data; boundary=#{boundary}"
    [headers, body.scrub!]
  end
end

def create_whitelisted_ips(agent_only = false)
  WhitelistedIp.destroy_all
  @account.make_current
  @account.reload
  wip = @account.build_whitelisted_ip
  wip.load_ip_info('127.0.1.1')
  wip.update_attributes('enabled' => true, 'applies_only_to_agents' => agent_only,
                        'ip_ranges' => [{ 'start_ip' => '127.0.1.1', 'end_ip' => '127.0.1.10' }])
end

include TestCaseMethods

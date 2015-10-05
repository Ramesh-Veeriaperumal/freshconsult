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
    response.body.must_match_json_expression json
  end

  def match_custom_json(response, json)
    response.must_match_json_expression json
  end

  # pass params that are to be wrapped by controller name for 'wrapped'
  # and the rest like 'id' for 'unwrapped'
  def construct_params(unwrapped, wrapped = false)
    params_hash = request_params.merge(unwrapped)
    params_hash.merge!(wrap_cname(wrapped)) if wrapped
    params_hash
  end

  def add_content_type
    @headers ||= {}
    @headers['CONTENT_TYPE'] = 'application/json'
  end

  def white_space
    ' ' * 300
  end

  def get_others_redis_key(key)
    newrelic_begin_rescue { $redis_others.get(key) }
  end

  def remove_others_redis_key(key)
    newrelic_begin_rescue { $redis_others.del(key) }
  end

  def set_others_redis_key(key, value, expires = 86_400)
    newrelic_begin_rescue do
      $redis_others.set(key, value)
      $redis_others.expire(key, expires) if expires
    end
  end

  def key
    API_THROTTLER % { host: 'localhost.freshpo.com' }
  end

  def api_limit_key
    FD_API_LIMIT % { host: 'localhost.freshpo.com' }
  end

  def default_api_limit_key
    'FD_DEFAULT_API_LIMIT'
  end

  EOL = "\015\012"  # "\r\n"
  # Encode params and image in multipart/form-data.
  def encode_multipart(params,image_param=nil,image_file_path=nil,content_type=nil, encoding=true)
    headers={}
    parts=[]
    boundary="234092834029834092830498"
    params.each_pair do |key,val|
      if val.is_a? Hash
        val.each_pair do |child_key, child_value|
          parts.push %{Content-Disposition: form-data; }+%{name="#{key}[#{child_key}]"#{EOL}#{EOL}#{child_value}#{EOL}}
        end
      elsif val.is_a? Array
        val.each do |x|
          parts.push %{Content-Disposition: form-data; }+%{name="#{key}[]"#{EOL}#{EOL}#{x}#{EOL}}
        end
      else
        parts.push %{Content-Disposition: form-data; }+%{name="#{key}"#{EOL}#{EOL}#{val}#{EOL}}
      end
    end
    if image_param
      image_part = \
        %{Content-Disposition: form-data; name="#{image_param}"; }+
        %{filename="#{File.basename(image_file_path)}"#{EOL}}+
        %{Content-Type: #{content_type}#{EOL}#{EOL}}
      file_read_params = encoding ? [image_file_path, encoding: "UTF-8"] : [image_file_path]
      image_part << File.read(*file_read_params) << EOL
      image_part = image_part.force_encoding("BINARY") if image_part.respond_to?(:force_encoding) && encoding
      parts.push(image_part)
    end
    body = parts.join("--#{boundary}#{EOL}")
    body = "--#{boundary}#{EOL}" + body + "--#{boundary}--"+EOL
    headers['CONTENT_TYPE']="multipart/form-data; boundary=#{boundary}"
    [ headers , body.scrub! ]
  end
end

include TestCaseMethods

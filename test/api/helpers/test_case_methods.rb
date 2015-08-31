module TestCaseMethods
  include TicketFieldsHelper

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
end

include TestCaseMethods

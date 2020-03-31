require_relative '../../test_helper'
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')
require_relative '../../../models/helpers/product_test_helper'
class WidgetApiFlowsTest < ActionDispatch::IntegrationTest
  include HelpWidgetsTestHelper
  include ProductTestHelper
  include SolutionsTestHelper
  include SolutionsHelper
  include SolutionBuilderHelper
  include SearchTestHelper

  def setup
    super
    before_each
  end

  def before_each
    @account.launch :help_widget
    product = create_new_product(@account, {})
    @widget = create_widget(product_id: product.id, solution_articles: true)
    @write_headers['HTTP_X_WIDGET_ID'] = @widget.id
    @client_id = UUIDTools::UUID.timestamp_create.hexdigest
    @write_headers['HTTP_X_CLIENT_ID'] = @client_id
  end

  def tear_down
    Account.unstub(:current)
    @widget.try(:destroy)
    super
  end

  def create_articles(visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], user = nil)
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @category = create_category_with_language_reset
    set_category
    params = article_params(status: 2, visibility: visibility)
    article_meta = create_article_with_language_reset(params)
    if visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      folder_meta = @account.solution_folder_meta.find(params[:folder_id])
      folder_meta.customer_folders.create(customer_id: user.company_id)
    end
    @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
  end

  def main_portal_language_id
    Language.find_by_code(@account.main_portal.language).id
  end

  def article_params(category: @category, status: nil, title: 'Test',
                     visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
    {
      title: title,
      description: title,
      folder_id: create_folder_with_language_reset(visibility: visibility,
                                                   category_id: category.id,
                                                   lang_codes: ['es', 'en'],
                                                   name: Faker::Name.name).id,
      status: status || 2
    }
  end

  def set_category
    @help_widget_category = HelpWidgetSolutionCategory.new
    @help_widget_category.help_widget = @widget
    @help_widget_category.solution_category_meta = @category
    @help_widget_category.save
  end

  def set_user_login_headers(name: 'Sagara', email: 'sagara@desert.com', exp: (Time.now.utc + 2.hours), additional_payload: {}, additional_operations: { remove_key: nil })
    if Account.current.help_widget_secret.blank?
      account_additional_settings = Account.current.account_additional_settings
      account_additional_settings.secret_key[:help_widget_secret] = SecureRandom.hex
      account_additional_setting.save!
    end
    remove_key = additional_operations[:remove_key]
    exp = exp.to_i if exp.instance_of?(Time)
    payload = { name: name, email: email, exp: exp }.merge!(additional_payload).reject { |key| key == remove_key }
    @write_headers['HTTP_X_WIDGET_AUTH'] = JWT.encode(payload, Account.current.help_widget_secret)
    exp
  end

  def ip_blocked_response
    { code: :ip_blocked, message: 'Your IPAddress is blocked by the administrator' }.with_indifferent_access
  end

  def test_create_ticket_with_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    post '/api/widget/tickets', '{"email": "datsan@hon.com", "description": "testdd_truested_ip"}', @write_headers
    assert_response 201
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_create_ticket_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    post '/api/widget/tickets', '{"email": "datsan@hon.com", "description": "testdd_truested_ip"}', @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_create_ticket_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    post '/api/widget/tickets', '{"email": "datsan@hon.com", "description": "testdd_truested_ip"}', @write_headers
    assert_response 201
  end

  def test_article_show_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    @article = create_articles
    get "/api/widget/solutions/article/#{@article.parent_id}", nil, @write_headers
    assert_response 200
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_show_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    get '/api/widget/solutions/article/1', nil, @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_show_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    get "/api/widget/solutions/article/#{@article.parent_id}", nil, @write_headers
    assert_response 200
  end

  def test_article_hit_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @article = create_articles
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    put "/api/widget/solutions/article/#{@article.parent_id}/hit", '{}', @write_headers
    assert_response 204
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_hit_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    put '/api/widget/solutions/article/1', '{}', @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_hit_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    put "/api/widget/solutions/article/#{@article.parent_id}/hit", '{}', @write_headers
    assert_response 204
  end

  def test_article_thumbs_up_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @article = create_articles
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    put "/api/widget/solutions/article/#{@article.parent_id}/thumbs_up", '{}', @write_headers
    assert_response 204
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_thumbs_up_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    put '/api/widget/solutions/article/1/thumbs_up', '{}', @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_thumbs_up_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    put "/api/widget/solutions/article/#{@article.parent_id}/thumbs_up", '{}', @write_headers
    assert_response 204
  end

  def test_article_thumbs_down_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    @article = create_articles
    put "/api/widget/solutions/article/#{@article.parent_id}/thumbs_down", '{}', @write_headers
    assert_response 204
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_thumbs_down_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    put '/api/widget/solutions/article/1/thumbs_down', '{}', @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_article_thumbs_down_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    put "/api/widget/solutions/article/#{@article.parent_id}/thumbs_down", '{}', @write_headers
    assert_response 204
  end

  def test_ticket_fields_index_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    get '/api/widget/ticket_fields', nil, @write_headers
    assert_response 200
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_ticket_fields_index_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    get '/api/widget/ticket_fields', nil, @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_ticket_fields_index_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    get '/api/widget/ticket_fields', nil, @write_headers
    assert_response 200
  end

  def test_serach_solution_results_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    @article = create_articles
    stub_private_search_response([@article]) do
      get '/api/widget/search/solutions', { term: 'test' }, @write_headers
    end
    assert_response 200
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_search_solution_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    stub_private_search_response([@article]) do
      get '/api/widget/search/solutions', { term: 'yest' }, @write_headers
    end
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_search_solution_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @article = create_articles
    stub_private_search_response([@article]) do
      get '/api/widget/search/solutions', { term: 'yest' }, @write_headers
    end
    assert_response 200
  end

  def test_attachment_create_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    @write_headers['CONTENT_TYPE'] = 'multipart/form-data'
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post '/api/widget/attachment', {}, @write_headers
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_bootstrap_trusted_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    set_user_login_headers
    @write_headers['CLIENT_IP'] = '127.0.1.2'
    get '/api/widget/bootstrap', {}, @write_headers
    assert_response 200
  ensure
    unset_login_support
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_bootstrap_with_invalid_ip
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    set_user_login_headers
    get '/api/widget/bootstrap', {}, @write_headers
    assert_response 403
    match_json(ip_blocked_response)
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_bootstrap_without_ip_whitelisting
    @write_headers['CLIENT_IP'] = '0.0.0.0'
    set_user_login_headers
    get '/api/widget/bootstrap', {}, @write_headers
    assert_response 200
  end
end

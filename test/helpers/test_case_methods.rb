module TestCaseMethods
  include TicketFieldsHelper

  def parse_response(response)
    JSON.parse(response)
    rescue
  end

  def with_forgery_protection
    old_value = @controller.allow_forgery_protection
    @controller.allow_forgery_protection = true
    yield
  ensure
    @controller.allow_forgery_protection = old_value
  end

  def with_caching(on = true)
    caching = @controller.perform_caching
    @controller.perform_caching = on
    yield
  ensure
    ActionController::Metal.perform_caching = caching
  end

  def stub_const(parent, const, value, &block)
    const = const.to_s
    old_value = parent.const_get(const)
    parent.const_set(const, value)
    yield
  ensure
    parent.const_set(const, old_value)
  end

  def assert_user_count(incremented = false)
    count = incremented ? (User.count + 1) : User.count
    yield
  ensure
    assert User.count == count
  end

  def clear_cache
    Rails.cache.clear
  end

  def request_params
    { version: 'v2', format: :json }
  end

  def match_json(json)
    response.body.must_match_json_expression json
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

  def other_user
    User.select{|x| @agent.can_assume?(x)}.first || create_dummy_customer
  end

  def user_without_monitorships
    User.includes(:monitorships).find { |x| x.id != @agent.id && x.monitorships.blank? } || add_new_user(@account) # changed as it should have user without any monitorship
  end

  def category_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph }
  end

  def forum_params
    fc = ForumCategory.first || create_test_category
    { description: Faker::Lorem.paragraph, forum_category_id: fc.id,
      forum_type: 2, forum_visibility: 1, name: Faker::Name.name }
  end

  def topic_params
    f = Forum.first
    { forum_id: f.id, title: Faker::Name.name }
  end

  def post_params(t)
    { body_html: Faker::Lorem.paragraph, topic_id: t.id }
  end

  def v2_category_payload
    category_params.to_json
  end

  def v1_category_payload
    { forum_category: category_params }.to_json
  end

  def v2_forum_payload
    forum_params.to_json
  end

  def v1_forum_payload
    { forum: forum_params }.to_json
  end

  def v1_topics_payload
    { topic: topic_params.merge(sticky: 0, locked: 0, body_html: Faker::Lorem.paragraph) }.to_json
  end

  def v2_topics_payload
    topic_params.merge(message_html: Faker::Lorem.paragraph).to_json
  end

  def v1_post_payload(t)
    { post: post_params(t) }.to_json
  end

  def v2_post_payload(t)
    post_params(t).to_json
  end

  def create_custom_field
    @default_fields = ticket_field_hash(@account.ticket_fields, @account)
    @default_fields.map { |f_d| f_d.delete(:level_three_present) }
    @default_fields.push(type: 'paragraph', field_type: 'custom_paragraph',
                         label: 'Problem',
                         label_in_portal: 'Problem',
                         description: '',
                         active: true,
                         required: false,
                         required_for_closure: false,
                         visible_in_portal: true,
                         editable_in_portal: true,
                         required_in_portal: false,
                         id: nil,
                         choices: [],
                         levels: [],
                         action: 'create')
    @default_fields
  end
end

include TestCaseMethods

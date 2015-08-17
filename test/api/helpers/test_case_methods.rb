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

  def stub_const(parent, const, value, &_block)
    const = const.to_s
    old_value = parent.const_get(const)
    parent.const_set(const, value)
    yield
  ensure
    parent.const_set(const, old_value)
  end

  def as_controller(controller, &_block)
    old_controller = self
    @controller = controller
    yield
  ensure
    @controller = old_controller
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

  def other_user
    User.find { |x| @agent.can_assume?(x) } || create_dummy_customer
  end

  def deleted_user
    user = User.find { |x| x.id != @agent.id } || create_dummy_customer
    user.update_column(:deleted, true)
    user.reload
  end

  def user_without_monitorships
    User.includes(:monitorships).find { |x| x.id != @agent.id && x.monitorships.blank? && x.deleted == 0 && x.blocked == 0 } || add_new_user(@account) # changed as it should have user without any monitorship
  end

  def v2_time_sheet_payload
    {
      start_time: 4.days.ago.to_s, executed_at: 89.days.ago.to_s, time_spent: '89:09', ticket_id: 1,
      agent_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
    }.to_json
  end

  def v1_time_sheet_payload
    {
      time_entry: {
        start_time: 4.days.ago.to_s, executed_at: 23.days.ago.to_s, hhmm: '89:09',
        user_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
      }
    }.to_json
  end

  def v2_time_sheet_update_payload
    {
      executed_at: 1.days.ago.to_s, billable: false, note: Faker::Lorem.paragraph
    }.to_json
  end

  def v1_time_sheet_update_payload
    {
      time_entry: { executed_at: 2.days.ago.to_s, billable: false, note: Faker::Lorem.paragraph }
    }.to_json
  end

  def v2_ticket_params
    @integrate_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    { email: Faker::Internet.email, cc_emails: [Faker::Internet.email, Faker::Internet.email], description:  Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '),
      priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: [Faker::Name.name, Faker::Name.name],
      due_by: 14.days.since.to_s, fr_due_by: 1.days.since.to_s, group_id: @integrate_group.id
    }
  end

  def v1_ticket_params
    { email: Faker::Internet.email, description:  Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '),
      priority: 2, status: 3, ticket_type: 'Problem', responder_id: @agent.id, source: 1,
      due_by: 14.days.since.to_s, frDueBy: 1.days.since.to_s, group_id: Group.find(1).id
    }
  end

  def category_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph }
  end

  def forum_params(fc = nil)
    fc = fc || ForumCategory.first || create_test_category
    { description: Faker::Lorem.paragraph, forum_category_id: fc.id,
      forum_type: 2, forum_visibility: 1, name: Faker::Name.name }
  end

  def topic_params(f = nil)
    f ||= Forum.first
    { forum_id: f.id, title: Faker::Name.name }
  end

  def post_params(t)
    { body_html: Faker::Lorem.paragraph, topic_id: t.id }
  end

  def v1_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_list: '1,3' }
  end

  def v2_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_ids: [1, 3] }
  end

  def api_company_params
    { name: Faker::Lorem.characters(10),  description: Faker::Lorem.paragraph, domains: Faker::Lorem.characters(5) }
  end

  def sla_policy_params
    { applicable_to: { company_ids: [1, 2] } }
  end

  def v1_sla_policy_params
    { conditions: { company_id: '1,2' } }
  end

  def v2_sla_policy_payload
    sla_policy_params.to_json
  end

  def v1_sla_policy_payload
    { helpdesk_sla_policy: v1_sla_policy_params }.to_json
  end

  def company_payload
    { company: api_company_params }.to_json
  end

  def v2_company_payload
    api_company_params.to_json
  end

  def group_payload
    { group: v1_group_params }.to_json
  end

  def v2_group_payload
    v2_group_params.to_json
  end

  def v2_category_payload
    category_params.to_json
  end

  def v1_category_payload
    { forum_category: category_params }.to_json
  end

  def v2_forum_payload(fc = nil)
    forum_params(fc).to_json
  end

  def v1_forum_payload
    { forum: forum_params }.to_json
  end

  def v1_topics_payload
    { topic: topic_params.merge(sticky: 0, locked: 0, body_html: Faker::Lorem.paragraph) }.to_json
  end

  def v2_topics_payload(f = nil)
    topic_params(f).merge(message_html: Faker::Lorem.paragraph).to_json
  end

  def v1_post_payload(t)
    { post: post_params(t) }.to_json
  end

  def v2_post_payload(t)
    post_params(t).to_json
  end

  def v1_ticket_payload
    { helpdesk_ticket: v1_ticket_params, helpdesk: { tags: "#{Faker::Name.name}, #{Faker::Name.name}" },
      cc_emails: "#{Faker::Internet.email}, #{Faker::Internet.email}" }.to_json
  end

  def v1_update_ticket_payload
    { helpdesk_ticket: v1_ticket_params.merge(cc_email: { cc_emails: [Faker::Internet.email, Faker::Internet.email], reply_cc: [Faker::Internet.email, Faker::Internet.email], fwd_emails: [] }),
      helpdesk: { tags: "#{Faker::Name.name}, #{Faker::Name.name}" } }.to_json
  end

  def v2_ticket_payload
    v2_ticket_params.to_json
  end

  def v2_ticket_update_payload
    v2_ticket_params.except(:due_by, :fr_due_by).to_json
  end

  def v1_note_payload
    { helpdesk_note: { body: Faker::Lorem.paragraph, to_emails: [Faker::Internet.email, Faker::Internet.email], private: true } }.to_json
  end

  def v2_note_payload
    { body: Faker::Lorem.paragraph, notify_emails: [Faker::Internet.email, Faker::Internet.email], ticket_id: Helpdesk::Ticket.first.display_id, private: true }.to_json
  end

  def v2_note_update_payload
    { body: Faker::Lorem.paragraph }.to_json
  end

  def v1_reply_payload
    { helpdesk_note: { body: Faker::Lorem.paragraph, source: 0, private: false,  cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] } }.to_json
  end

  def v2_reply_payload
    { body:  Faker::Lorem.paragraph, cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] }.to_json
  end

  def v1_contact_params
    # comp  = Company.first || create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10), phone: '1234567890',
      mobile: '1234567891', description: Faker::Lorem.characters(20), email: Faker::Internet.email,  job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', tag_names: "#{Faker::Lorem.characters(5)}, #{Faker::Lorem.characters(5)}"
    }
  end

  def v2_contact_params
    # comp  = Company.first || create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10),  phone: '1234567892',
      mobile: '1234567893', description: Faker::Lorem.characters(20), email: Faker::Internet.email,  job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', tags: [Faker::Lorem.characters(5), Faker::Lorem.characters(5)]
    }
  end

  def v1_contact_payload
    { user: v1_contact_params }.to_json
  end

  def v2_contact_payload
    v2_contact_params.to_json
  end

  def v1_contact_update_payload
    { user: v1_contact_params.except(:name, :email) }.to_json
  end

  def v2_contact_update_payload
    v2_contact_params.except(:name, :email).to_json
  end
end

include TestCaseMethods

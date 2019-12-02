module SlaTestHelper
  def ticket_params_hash_sla
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    { email: email, cc_emails: cc_emails, description: description, subject: subject,
      priority: TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low], status: 2, type: 'Incident', responder_id: @agent.id, source: 1, tags: tags }
  end

  def sla_policy
    conditions = { 'ticket_type' => ['Incident'] }
    resolution_time = [7200, 10_800, 14_400, 18_000] # [urgent, high, medium, low]
    response_time = [3600, 7200, 10_800, 14_400]
    next_response_time = [nil, 7200, 10_800, 14_400]
    build_sla_policy(true, conditions, {}, {}, resolution_time: resolution_time, response_time: response_time, next_response_time: next_response_time)
  end

  def build_sla_policy(is_active = true, conditions = {}, response_rule = '', resolution_rule = '', options = {})
    sla_policy = FactoryGirl.build(
      :sla_policies,
      name: options[:name] || Faker::Lorem.words(5),
      description: options[:description] || Faker::Lorem.paragraph,
      account_id: @account.id,
      conditions: conditions,
      datatype: {
        'ticket_type' => 'text'
      },
      active: is_active,
      escalations: {
        'response' => response_rule,
        'resolution' => resolution_rule
      }
    )
    sla_policy.save
    create_sla_details(sla_policy.id, options[:response_time] || [], options[:resolution_time] || [], options[:override_bhrs] || [],  options[:next_response_time] || [])
  end

  def create_sla_details(sla_policy_id, response_time = [], resolution_time = [], override_bhrs = [], next_response_time = [])
    details = {
      '0' => { level: 'urgent', priority: '4' },
      '1' => { level: 'high', priority: '3' },
      '2' => { level: 'medium', priority: '2' },
      '3' => { level: 'low', priority: '1' }
    }

    details.each_pair do |key, value|
      sla_details = FactoryGirl.build(:sla_details, name: "SLA for #{value[:level]} priority",
                                                    priority: value[:priority], response_time: (response_time[key.to_i] || '900'),
                                                    next_response_time: (next_response_time[key.to_i]),
                                                    resolution_time: (resolution_time[key.to_i] || '900'), account_id: @account.id,
                                                    override_bhrs: override_bhrs[key.to_i] || false, escalation_enabled: '1', sla_policy_id: sla_policy_id)
      sla_details.save
    end
  end

  def freeze_time_now(time)
    Time.zone = @account.time_zone
    Timecop.freeze(time)
    yield
    Timecop.return
    Time.zone = @account.time_zone
  end

  def get_datetime(time, day)
    date = Date.parse(day)
    Time.zone.parse("#{date} #{time}")
  end

end

module SlaPolicyTestHelper

  # each agents element should be an array of agent ids as we can have more than one agent in escalation rule
  def create_escalation_rule(time = [], agents = [])

    raise "Time and agent should have same size and not empty" if time.length != agents.length or time.blank?
    rule = {}
    (1..time.length).each do |level|
      rule[level.to_s] = {:time => time[level - 1], :agents_id => agents[level - 1]}
    end
    rule
  end

  def create_sla_policy(is_active = true, conditions = {}, response_rule = "", resolution_rule = "", options = {})
    sla_policy = FactoryGirl.build(
                                    :sla_policies, 
                                    :name => options[:name] || Faker::Lorem.words(5), 
                                    :description => options[:description] || Faker::Lorem.paragraph,
                                    :account_id => @account.id,
                                    :conditions => conditions,
                                    :datatype => {
                                      "ticket_type" => "text"
                                    }, 
                                    :active => is_active,
                                    :escalations => {
                                      "response" => response_rule, 
                                      "resolution" => resolution_rule
                                    }
                                  )
    sla_policy.save
    create_sla_details(sla_policy.id, options[:response_time] || [], options[:resolution_time] || [], options[:override_bhrs] || [])
  end

  def create_sla_details(sla_policy_id, response_time = [], resolution_time = [], override_bhrs = [])
    details = {
                "0" => { :level => "urgent", :priority => "4" }, 
                "1" => { :level => "high", :priority => "3" },
                "2" => { :level => "medium", :priority => "2" },
                "3" => { :level => "low", :priority => "1" }
              }

    details.each_pair do |key, value|
      sla_details = FactoryGirl.build(:sla_details, :name => "SLA for #{value[:level]} priority",
                                      :priority => value[:priority], :response_time => (response_time[key.to_i] || "900"),
                                      :resolution_time => (resolution_time[key.to_i] || "900"), :account_id => @account.id,
                                      :override_bhrs => override_bhrs[key.to_i] || false, :escalation_enabled => "1", :sla_policy_id => sla_policy_id)
      sla_details.save
    end
  end

  def get_datetime(time)
    if Date.today.saturday?
      Time.zone.parse(time).advance(:days => 2)
    elsif Date.today.sunday?
      Time.zone.parse(time).advance(:days => 1)
    else
      Time.zone.parse(time)
    end
  end

end
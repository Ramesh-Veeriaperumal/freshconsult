module SlaPoliciesHelper

  SLA_DETAILS = {
    "4" => { :level=>"urgent" },
    "3" => { :level=>"high" },
    "2" => { :level=>"medium" },
    "1" => { :level=>"low" }
  }

  def create_sla_policy(new_agent)
    customer = FactoryGirl.build(:customer, :name => Faker::Name.name)
    customer.save
    sla_policy = FactoryGirl.build(:sla_policies,
      :name => Faker::Lorem.words,
      :description => Faker::Lorem.paragraph,
      :active => true, :account_id => @account.id,
      :datatype => { :ticket_type => "Problem" },
      :conditions => {
        "group_id" => ["1"],
        "company_id" => ["#{customer.id}"]
      },
      :escalations => { 
        "response" => { "1" => { :time =>"1800", :agents_id => ["#{@agent.id}"] } },
        "resolution" => { "1" => { :time => "3600", :agents_id => ["#{new_agent.id}"] } }
      }
    )
    sla_policy.escalations.merge({
      "next_response" => { "1" => { :time =>"1800", :agents_id => ["#{@agent.id}"] } } 
    }) if @account.next_response_sla_enabled?
    sla_policy.save(validate: false)

    sla_target_hash = {}
    if @account.sla_policy_revamp_enabled?
      sla_target_time = ActiveSupport::HashWithIndifferentAccess.new({ first_response_time: "PT15M", resolution_due_time: "PT15M" })
      sla_target_time[:every_response_time] = "PT15M" if @account.next_response_sla_enabled?
      sla_target_hash = { sla_target_time: sla_target_time }
    end
    sla_target_hash.merge!({ response_time: "900", resolution_time: "900" })
    sla_target_hash[:next_response_time] = "900" if @account.next_response_sla_enabled?

    SLA_DETAILS.each_pair do |k,v|
      sla_details = FactoryGirl.build(:sla_details, {
        :name=>"SLA for #{v[:level]} priority",
        :priority=>"#{k}",
        :account_id => @account.id,
        :override_bhrs=>"false",
        :escalation_enabled=>"1",
        :sla_policy_id => sla_policy.id
      }.merge!(sla_target_hash))
      sla_details.save(validate: false)
		end
    sla_policy
	end

	def sla_detail_ids(sla_policy)
		ids = []
		sla_policy.sla_details.each do |detail|
			ids << detail.id
		end
		ids
	end

	def sla_details(ids=[])
		{
			"0"=> { :name=>"SLA for urgent priority", :priority=>"4", :id=>ids[0] || "", :response_time=>"900", :resolution_time=>"900", 
			 	                     :override_bhrs=>"false", :escalation_enabled=>"1"},
            "1"=> { :name=>"SLA for high priority", :priority=>"3", :id=>ids[1] || "", :response_time=>"3600", :resolution_time=>"7200 ", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"}, 
            "2"=> { :name=>"SLA for medium priority", :priority=>"2", :id=>ids[2] || "", :response_time=>"86400", :resolution_time=>"172800", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"},
			"3"=> { :name=>"SLA for low priority", :priority=>"1", :id=>ids[3] || "", :response_time=>"2592000", :resolution_time=>"5184000", 
							 	     :override_bhrs=>"false", :escalation_enabled=>"1"}
		}
	end

	def sla_policies(agent_1,agent_2,options={})
		{
			:name => options[:name] || "", 
			:id=> options[:id] || "", 
			:description => options[:description] || Faker::Lorem.paragraph,
            :datatype => {:ticket_type => "text"}, 
            :conditions => {"ticket_type" => options[:ticket_type].present? ? ["#{options[:ticket_type]}"] : "", "company_id" =>""}, 
            :escalations => { "response" =>{"1"=>{:time =>"0", :agents_id =>["#{@agent.id}"]}}, 
			                  "resolution" =>{"1"=>{:time =>"0", :agents_id =>["#{agent_1}"]},"2"=>{:time =>"1800", :agents_id =>["#{agent_2}"]}}
			                }
		}
	end
end
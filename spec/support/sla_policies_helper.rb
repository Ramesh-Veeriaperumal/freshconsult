module SlaPoliciesHelper

	def create_sla_policy(new_agent)
		customer = FactoryGirl.build(:customer, :name => Faker::Lorem.words(1))
        customer.save
		sla_policy = FactoryGirl.build(:sla_policies, :name => Faker::Lorem.words(1), :description => Faker::Lorem.paragraph, :account_id => @account.id, 
			:datatype => {:ticket_type => "text"},:conditions =>{ "group_id" =>["1"], "company_id" =>["#{customer.id}"]},
			:escalations =>{"response"=>{"1"=>{:time =>"1800", :agents_id =>["#{@agent.id}"]}}, 
			                "resolution"=>{"1"=>{:time=>"3600", :agents_id=>["#{new_agent.id}"]}}
			                })
		sla_policy.save(validate: false)
    details = {"4"=>{:level=>"urgent"},"3"=>{:level=>"high"}, "2"=>{:level=>"medium"}, "1"=>{:level=>"low"}}
    details.each_pair do |k,v|
			sla_details = FactoryGirl.build(:sla_details, :name=>"SLA for #{v[:level]} priority", :priority=>"#{k}", :response_time=>"900", :resolution_time=>"900", 
				 	                     :account_id => @account.id, :override_bhrs=>"false", :escalation_enabled=>"1", :sla_policy_id => sla_policy.id)
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
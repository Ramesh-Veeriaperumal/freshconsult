module SlaPoliciesHelper

	def create_sla_policy(new_agent)
		customer = Factory.build(:customer, :name => Faker::Name.name)
        customer.save
		sla_policy = Factory.build(:sla_policies, :name => Faker::Name.name, :description => Faker::Lorem.paragraph, :account_id => @account.id, 
			:datatype => {:ticket_type => "text"},:conditions =>{ :group_id =>["1"], :company_id =>["#{customer.id}"]},
			:escalations =>{:response=>{"1"=>{:time =>"1800", :agents_id =>["#{@agent.id}"]}}, 
			                :resolution=>{"1"=>{:time=>"3600", :agents_id=>["#{new_agent.id}"]}}
			                })
		sla_policy.save(false)
        details = {"4"=>{:level=>"urgent"},"3"=>{:level=>"high"}, "2"=>{:level=>"medium"}, "1"=>{:level=>"low"}}
        details.each_pair do |k,v|
		sla_details = Factory.build(:sla_details, :name=>"SLA for #{v[:level]} priority", :priority=>"#{k}", :response_time=>"900", :resolution_time=>"900", 
			 	                     :account_id => @account.id, :override_bhrs=>"false", :escalation_enabled=>"1", :sla_policy_id => sla_policy.id)
		sla_details.save(false)
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
end
module RolesHelper

	def assign_user_privileges(role,params = {})
		new_agent = Factory.build(:agent, :occasional => "false", 
			                              :scoreboard_level_id => "1", 
			                              :signature_html=> params[:signature_html], 
			                              :user_id => "",
			                              :ticket_permission => "1")
	    new_user = Factory.build(:user, :helpdesk_agent => true,
	                                    :name => params[:name],
	                                    :email => params[:email],
	                                    :time_zone => "Chennai",
	                                    :job_title =>"Spec Agent",
	                                    :phone => Faker::PhoneNumber.phone_number, 
		                                :language => "en", 
		                                :delta => 1,
		                                :role_ids => ["#{role.id}"],
		                                :privileges => role.privileges,
		                                :active => 1)
	    new_user.agent = new_agent
	    new_user.save(false)
	    new_user
	end

	def verify_user_privileges(user, privileges)
		privileges.each do |privilege|
			res = user.privilege?(privilege.to_sym)
			return false unless res
		end
		return true
	end

	def create_role(params = {})
		test_role = Factory.build(:roles, :name => params[:name], :description => Faker::Lorem.paragraph, 
		                            :privilege_list => params[:privilege_list] )
		test_role.save(false)
		test_role
	end
end
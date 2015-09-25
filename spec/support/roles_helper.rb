module RolesHelper

	def create_role(params = {})
		test_role = FactoryGirl.build(:roles, :name => params[:name], :description => Faker::Lorem.paragraph, 
		                            :privilege_list => params[:privilege_list] )
		test_role.save(validate: false)
		test_role
	end

	def verify_user_privileges(user, privileges)
		privileges.each do |privilege|
			next if privilege.blank? || privilege == "0"
			privilege = privilege.to_sym
			return false unless user.privilege?(privilege)
			# Remove this check once new privileges list shown in UI
			if (new_privileges = Helpdesk::PrivilegesMap::MIGRATION_MAP).keys.include?(privilege)
				new_privileges.fetch(privilege).each do |new_priv|
					return false unless user.privilege?(new_priv)
				end
			end
		end
		return true
	end
end
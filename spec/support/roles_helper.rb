module RolesHelper

	def create_role(params = {})
		test_role = Factory.build(:roles, :name => params[:name], :description => Faker::Lorem.paragraph, 
		                            :privilege_list => params[:privilege_list] )
		test_role.save(false)
		test_role
	end

	def verify_user_privileges(user, privileges)
		privileges.each do |privilege|
			next if privilege.blank? || privilege == "0"
			res = user.privilege?(privilege.to_sym)
			return false unless res
		end
		return true
	end
end
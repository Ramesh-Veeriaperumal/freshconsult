class Solution::Builder

	OBJECTS = [:solution_category, :solution_folder, :solution_article]

	class << self

		OBJECTS.each do |obj|
			define_method obj.to_s.split("_")[1] do |args = {}|
				Solution::Object.new(HashWithIndifferentAccess.new(args), obj).return_back
			end
		end

	end

end

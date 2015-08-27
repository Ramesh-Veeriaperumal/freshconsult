class Solution::Builder

	OBJECTS = [:solution_category, :solution_folder, :solution_article]

	class << self

		OBJECTS.each do |obj|
			define_method obj.to_s.split("_")[1] do |args = {}|
				obj_builder = Solution::Object.new(args, obj)
				obj_builder.solution_obj
			end
		end

	end

end

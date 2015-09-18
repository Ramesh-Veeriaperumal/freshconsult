#can be removed once we start creating everything through meta records
class Solution::MappingTablesObserver < ActiveRecord::Observer

	observe PortalSolutionCategory, Mobihelp::AppSolution, Solution::CustomerFolder

	PARENT_KEYS = {
		"PortalSolutionCategory" => ["solution_category_meta_id", "solution_category_id"], 
		"Solution::CustomerFolder" => ["folder_meta_id", "folder_id"],
		"Mobihelp::AppSolution" => ["solution_category_meta_id", "category_id"]
	}

	def before_save(obj)
		# obj.send("#{PARENT_KEYS[obj.class.name].first}=", obj.send(PARENT_KEYS[obj.class.name].last))
	end
end
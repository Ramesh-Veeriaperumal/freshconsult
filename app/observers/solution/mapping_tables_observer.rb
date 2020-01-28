#can be removed once we start creating everything through meta records
class Solution::MappingTablesObserver < ActiveRecord::Observer

	observe PortalSolutionCategory, Solution::CustomerFolder

	PARENT_KEYS = {
		"PortalSolutionCategory" => ["solution_category_meta_id", "solution_category_id"], 
		'Solution::CustomerFolder' => ['folder_meta_id', 'folder_id']
	}

	def before_save(obj)
		# obj.safe_send("#{PARENT_KEYS[obj.class.name].first}=", obj.safe_send(PARENT_KEYS[obj.class.name].last))
	end
end

# TODO-MULTILINGUAL - can be removed once we start creating everything through meta records

class Solution::MetaObserver < ActiveRecord::Observer

	observe Solution::CategoryMeta, Solution::FolderMeta, Solution::ArticleMeta

	def after_create(meta_obj)
		# scoper = meta_obj.class.model_name.singular.chomp("_meta").pluralize
		# child_obj = Account.current.send(scoper).find(meta_obj.id)
		# child_obj.parent_id = meta_obj.id
		# child_obj.language = Account.current.language
		# child_obj.save(:validate => false)
	end
end
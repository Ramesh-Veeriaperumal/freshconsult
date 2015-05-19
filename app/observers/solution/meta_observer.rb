# TODO-MULTILINGUAL - can be removed once we start creating everything through meta records

class Solution::MetaObserver < ActiveRecord::Observer

	observe Solution::CategoryMeta, Solution::FolderMeta, Solution::ArticleMeta

	def after_create(meta_obj)
		scoper = meta_obj.class.model_name.singular.chomp("_meta").pluralize
		child_obj = Account.current.send(scoper).find(meta_obj.id)
		child_obj.class.where("id = #{child_obj.id}").
			update_all(:parent_id => meta_obj.id, 
			:language_id => Solution::MetaMethods::LANGUAGE_MAPPING[Account.current.language][:language_id])
	end
end
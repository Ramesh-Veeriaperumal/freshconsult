# TODO-MULTILINGUAL - can be removed once we start creating everything through meta records

class Solution::MetaObserver < ActiveRecord::Observer

	observe Solution::CategoryMeta, Solution::FolderMeta, Solution::ArticleMeta

	def after_commit(meta_obj)
		return unless meta_obj.send(:"transaction_include_action?", :create)
		klass = meta_obj.class.model_name.chomp("Meta").constantize
		klass.where({
				:id => meta_obj.id, 
				:account_id => meta_obj.account_id
			}).update_all({
				:parent_id => meta_obj.id, 
				:language_id => Language.find_by_code(Account.current.language).id
			})
	end
end
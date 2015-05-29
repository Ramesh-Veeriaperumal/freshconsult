class Solution::LanguageObserver < ActiveRecord::Observer

	observe Solution::Category, Solution::Folder, Solution::Article

	def before_create(obj)
		obj.language = Account.current.language if obj.language.blank?
	end
end
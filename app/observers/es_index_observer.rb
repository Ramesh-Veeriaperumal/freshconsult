class EsIndexObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, Helpdesk::Note, User, Customer, Solution::Article, Topic, Post

	def after_commit_on_create(model)
		return if [:"Helpdesk::Note"].include? model.class.name.to_sym
		model.update_es_index
	end

	def after_commit_on_update(model)
		model.update_es_index
	end

	def after_commit_on_destroy(model)
		model.update_es_index if [:User,:Post].include? model.class.name.to_sym
		model.remove_es_document if [
			:"Helpdesk::Ticket",:Customer,:"Solution::Article",:Topic].include? model.class.name.to_sym
	end

end
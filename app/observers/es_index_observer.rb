class EsIndexObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, User, UserEmail, Customer, Solution::Article, Topic, Post, Helpdesk::Tag, Freshfone::Caller,Admin::CannedResponses::Response

	def after_commit_on_create(model)
		model.update_es_index
	end

	def after_commit_on_update(model)
		model.update_es_index if model.respond_to?(:search_fields_updated?) ? model.send(:search_fields_updated?) : true
		model.update_notes_es_index if [:"Helpdesk::Ticket"].include? model.class.name.to_sym
	end

	def after_commit_on_destroy(model)
		model.update_es_index if [:User,:Post].include? model.class.name.to_sym
		model.remove_es_document if [
			:"Helpdesk::Ticket",:Company,:"Solution::Article",:Topic, :"Helpdesk::Tag", :"Freshfone::Caller", :"Admin::CannedResponses::Response"].include? model.class.name.to_sym
	end

end
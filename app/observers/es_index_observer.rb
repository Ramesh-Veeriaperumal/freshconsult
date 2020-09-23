class EsIndexObserver < ActiveRecord::Observer

  observe Helpdesk::Ticket, User, UserEmail, Customer, Solution::Article, Topic, Post, Helpdesk::Tag, Freshfone::Caller
  
  MODELS = [:"Helpdesk::Ticket",:Company,:"Solution::Article",:Topic, :"Helpdesk::Tag", :"Freshfone::Caller"]

  def after_commit(model)
    return unless model.account.esv1_enabled?

    if model.safe_send(:transaction_include_action?, :create)
      commit_on_create(model)
    elsif model.safe_send(:transaction_include_action?, :update)
      commit_on_update(model)  
    elsif model.safe_send(:transaction_include_action?, :destroy)
      commit_on_destroy(model) 
    end
    true
  end
  
  private
  
	def commit_on_create(model)
		model.update_es_index
	end

	def commit_on_update(model)
		model.update_es_index if model.respond_to?(:search_fields_updated?) ? model.safe_send(:search_fields_updated?) : true
		model.update_notes_es_index if [:"Helpdesk::Ticket"].include? model.class.name.to_sym
	end

	def commit_on_destroy(model)
		model.update_es_index if [:User,:Post].include? model.class.name.to_sym
		unless model.account.features_included?(:archive_tickets)
		  model.remove_es_document if MODELS.include? model.class.name.to_sym
		else
      if [:"Helpdesk::Ticket"].include? model.class.name.to_sym
        model.archive ? model.remove_from_es_count : model.remove_es_document
      elsif MODELS.include? model.class.name.to_sym
        model.remove_es_document
      end
		end
	end

end

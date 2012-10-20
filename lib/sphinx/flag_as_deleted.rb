module Sphinx	
	class FlagAsDeleted < Resque::FreshdeskBase
		@queue = "ticket_sphinx_queue"
		
		def self.perform(args)
			args.symbolize_keys!
			document_id = args[:document_id]
			model =  args[:model_name].constantize
			config = ThinkingSphinx::Configuration.instance
    		model.core_index_names.each do |index|
      			config.client.update(index,['sphinx_deleted'],{document_id => [1]}) if ThinkingSphinx.sphinx_running? &&
      			ThinkingSphinx.search_for_id(document_id, index)
    	 	end
      		true
	 	end
	end
end
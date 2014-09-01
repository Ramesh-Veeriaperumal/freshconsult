class ConvertContentOfSignatureHtmlToHtml < ActiveRecord::Migration
  	def self.up
		Account.all.each do |account|
        	account.all_agents.each do |agent| 	        
        		agent.update_attribute(:signature_html, RedCloth.new(agent.signature).to_html) if agent.signature
 	    	end
	 	end  
   	end

	def self.down
	end
end

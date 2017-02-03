module Ember
  module Search
	  class SpotlightController < ApiApplicationController

  	include ::Search::V2::AbstractController

    private

	    def esv2_agent_models
	      @@esv2_agent_spotlight ||= {
	        'company'       => { model: 'Company',            associations: [] }, 
	        'topic'         => { model: 'Topic',              associations: [ { forum: :forum_category }, :user ] }, 
	        'ticket'        => { model: 'Helpdesk::Ticket',   associations: [ { flexifield: :flexifield_def }, { requester: :avatar }, :ticket_states, :ticket_old_body, :ticket_status, :responder, :group, { :ticket_states => :tickets } ] },
	        'archiveticket' => { model: 'Helpdesk::ArchiveTicket',     associations: [] }, 
	        'article'       => { model: 'Solution::Article',  associations: [ :user, :article_body, :recent_author, { :solution_folder_meta => :en_folder } ] }, 
	        'user'          => { model: 'User',               associations: [ :avatar, :customer, :default_user_company, :companies ] }
	      }
	    end

	    def esv2_portal_models
	      @@esv2_portal_spotlight ||= {
	        'ticket'        => { model: 'Helpdesk::Ticket',         associations: [ :ticket_old_body, :group, :requester, :company ] },
	        'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] },
	        'topic'         => { model: 'Topic',                    associations: [ :forum ] },
	        'article'       => { model: 'Solution::Article',        associations: [:article_body, { :solution_folder_meta => :solution_category_meta } ] }
	      }
	    end

	    def esv2_contact_merge_models
	      @@esv2_contact_merge_models ||= {
	        'user' => { model: 'User', associations: [{ :account => :features }, :company, :user_emails] }
	      }
	    end
  	end
  end
end
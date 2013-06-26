class Helpdesk::MergeTicketsController < ApplicationController

	include ActionView::Helpers::DateHelper
	include Helpdesk::MergeTicketActions

	before_filter :load_source_tickets, :only => [ :bulk_merge, :merge, :complete_merge ]

	before_filter :load_target_ticket, :only => [ :merge, :complete_merge ]

	# MERGE_TICKET_STATES_PRIORITY = {
 #    "created_at" => 4,
 #    "agent_responded_at" => 3,
 #    "requester_responded_at" => 2,
 #    "resolved_at" => 2,
 #    "closed_at" => 1
 #  }

 	SEARCH_METHODS = [ "with_display_id", "with_requester" ]

 	SEARCH_KEYS = [ "display_id", "subject" ]

    def bulk_merge
        @ticket_search = Array.new
        render :partial => "helpdesk/merge/bulk_merge", :locals => { :redirect_back => params[:redirect_back]}
    end

	def merge_search
		items = []
		if params[:search_method] == 'with_subject' && current_account.es_enabled?
      		options = { :load => { :include => 'requester' }, :size => 1000, :preference => :_primary_first }
      		es_items = Tire.search [current_account.search_index_name], options do |search|
        		search.query do |query|
          			query.filtered do |f|
            			if SearchUtil.es_exact_match?(params[:search_string])
              				f.query { |q| q.text :subject, SearchUtil.es_filter_exact(params[:search_string]), :type => :phrase }
            			else
              				f.query { |q| q.string SearchUtil.es_filter_key(params[:search_string]), :fields => ['subject'], :analyzer => "include_stop" }
            			end
            			f.filter :terms, :_type => ['helpdesk/ticket']
            			f.filter :term, { :deleted => false }
            			f.filter :term, { :spam => false }
            			f.filter :term, { :account_id => current_account.id }
            			if current_user.restricted?
              				user_groups = current_user.group_ticket_permission ? current_user.agent_groups.map(&:group_id) : []
              				f.filter :or, { :not => { :exists => { :field => :responder_id } } },
                            			  { :term => { :responder_id => current_user.id } },
                            			  { :terms => { :group_id => user_groups } }
            			end
          			end
        		end
      		end
      		items = es_items.results
		else
			if params[:search_method] == 'with_subject'
				with_params = { :account_id => current_account.id, :deleted => false }
				select_str = "*"
    			if current_user.restricted?
    				with_params[:restricted] = 1
    				restriction = "responder_id = #{current_user.id} OR responder_id = #{SearchUtil::DEFAULT_SEARCH_VALUE}"
	    			if current_user.agent.group_ticket_permission
	      				restriction += " OR group_id = #{SearchUtil::DEFAULT_SEARCH_VALUE}"
	      				restriction = current_user.agent_groups.reduce(restriction) do |val, ag|
	         				"#{val} OR group_id = #{ag.group_id}"
	      				end
	    			end
	    			select_str += ", IF( #{restriction}, 1, 0 ) AS restricted"
	    		end
				items = ThinkingSphinx.search :conditions => { :subject => params[:search_string] },
									  :include => :requester,
                                      :with => with_params,
                                      :classes => [ Helpdesk::Ticket ],
                                      :sphinx_select => select_str,
                                      :star => true,
                                      :order => :status,
                                      :limit => 1000
			else
      			scope = current_account.tickets.permissible(current_user)
				items = scope.send( params[:search_method], params[:search_string] ) if SEARCH_METHODS.include?(params[:search_method])
			end
		end
		r = {:results => items.map{|i| {
				:display_id => i.display_id, :subject => i.subject, :title => h(i.subject),
				:searchKey => 
					(params[:key] == 'requester') ? i[:requester_name] : ( i.send(params[:key]).to_s if SEARCH_KEYS.include?(params[:key]) ),  
			 	:info => t("ticket.merge_ticket_list_status_created_at", 
					:username => "<span class='muted'>#{( (params[:key] == 'requester') ? i[:requester_name] : i.requester )}</span>", 
					:time_ago => time_ago_in_words(i.created_at) ) }}}
		respond_to do |format|
		  format.json { render :json => r.to_json }
		end
	end

	def merge
		render :partial => "helpdesk/merge/bulk_merge_script"
	end

	def complete_merge
		handle_merge
		flash[:notice] = t("helpdesk.merge.bulk_merge.target_note_description3", 
										:count => @source_tickets.length, 
										:target_ticket_id => @target_ticket.display_id, 
										:source_tickets => @source_tickets.map(&:display_id).to_sentence)
    	redirect_to ( params[:redirect_back].eql?("true") ? :back : helpdesk_ticket_path(@target_ticket) )
	end

	protected

		# def merge_sort items=@source_tickets
		# 	items.sort_by{ |i| [ MERGE_TICKET_STATES_PRIORITY[i.ticket_states.current_state], i.created_at ]}.reverse
		# end

		def load_target_ticket
			@target_ticket = current_account.tickets.find_by_display_id(params[:target][:ticket_id])
		end

		def load_source_tickets
			@source_tickets = current_account.tickets.find(:all, :conditions =>{:display_id => params[:source_tickets]},
                                                            :order => "status, created_at DESC")
		end
end
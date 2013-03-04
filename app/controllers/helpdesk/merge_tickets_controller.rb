class Helpdesk::MergeTicketsController < ApplicationController

	include ActionView::Helpers::DateHelper
	include Helpdesk::MergeTicketActions

	before_filter :load_source_tickets, :only => [ :bulk_merge, :merge, :complete_merge ]

	before_filter :load_target_ticket, :only => [ :merge, :complete_merge ]

	MERGE_TICKET_STATES_PRIORITY = {
    "created_at" => 4,
    "agent_responded_at" => 3,
    "requester_responded_at" => 2,
    "resolved_at" => 2,
    "closed_at" => 1
  }

  def bulk_merge
    @ticket_search = Array.new
    @source_tickets = merge_sort
		render :partial => "helpdesk/merge/bulk_merge"
  end

	def merge_search
		scope = current_account.tickets.permissible(current_user)
		items = (params[:key] == "display_id") ? scope.send( params[:search_method], params[:search_string] ) :
																						merge_sort(scope.send( params[:search_method], params[:search_string] ))
		r = {:results => items.map{|i| {
					:display_id => i.display_id, :subject => i.subject, 
					:searchKey => (params[:key] == 'requester') ? i[:requester_name] : i.send(params[:key]).to_s, 
				 	:info => t("ticket.merge_ticket_list_status_"+i.ticket_states.current_state, 
						:username => "<span class='muted'>#{( (params[:key] == 'requester') ? i[:requester_name] : i.requester )}</span>", 
						:time_ago => time_ago_in_words(i.ticket_states.send(i.ticket_states.current_state))) }}}
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
		redirect_to :back
	end

	protected

		def merge_sort items=@source_tickets
			items.sort_by{ |i| [ MERGE_TICKET_STATES_PRIORITY[i.ticket_states.current_state], i.created_at ]}.reverse
		end

		def load_target_ticket
			@target_ticket = current_account.tickets.find_by_display_id(params[:target][:ticket_id])
		end

		def load_source_tickets
			@source_tickets = current_account.tickets.find(:all, :conditions =>{:display_id => params[:source_tickets]})
		end
end
class Helpdesk::MergeTicketsController < ApplicationController

	include Helpdesk::MergeTicketActions

	before_filter :load_source_tickets, :only => [ :bulk_merge, :merge, :complete_merge ]

	before_filter :load_target_ticket, :only => [ :merge, :complete_merge ]
	before_filter :set_native_mobile, :only => [:complete_merge]

	# MERGE_TICKET_STATES_PRIORITY = {
 #    "created_at" => 4,
 #    "agent_responded_at" => 3,
 #    "requester_responded_at" => 2,
 #    "resolved_at" => 2,
 #    "closed_at" => 1
 #  }

    def bulk_merge
        render :partial => "helpdesk/merge/bulk_merge", :locals => { :redirect_back => params[:redirect_back]}
    end

	def merge
		render :partial => "helpdesk/merge/bulk_merge_script"
	end

	def complete_merge
		if @source_tickets.present? && @target_ticket.present?
			handle_merge
			respond_to do |format|
				format.html do
					flash[:notice] = t("helpdesk.merge.bulk_merge.target_note_description3",
											:count => @source_tickets.length,
											:target_ticket_id => @target_ticket.display_id,
											:source_tickets => @source_tickets.map(&:display_id).to_sentence)
					redirect_to ( params[:redirect_back].eql?("true") ? :back : helpdesk_ticket_path(@target_ticket) )
				end
				format.nmobile { render :json => { :result => true, :count => @source_tickets.length,
											:target_ticket_id => @target_ticket.display_id,
											:source_tickets => @source_tickets.map(&:display_id).to_sentence }}
			end
		else
			respond_to do |format|
				format.html do
					flash[:error] = t("flash.merge_ticket_failed")
					redirect_to ( params[:redirect_back].eql?("true") ? :back : helpdesk_ticket_path(@target_ticket) )
				end
				format.nmobile { render :json => {:error => t(:'flash.merge_ticket_failed')}, :status => :forbidden}
			end
		end
	end

	protected

		# def merge_sort items=@source_tickets
		# 	items.sort_by{ |i| [ MERGE_TICKET_STATES_PRIORITY[i.ticket_states.current_state], i.created_at ]}.reverse
		# end

		def load_target_ticket
			@target_ticket = current_account.tickets.permissible(current_user).find_by_display_id(params[:target][:ticket_id])
		end

		def load_source_tickets
			@source_tickets = current_account.tickets
													.permissible(current_user)
													.where(:display_id => params[:source_tickets])
                          .order("status, created_at DESC")
		end
end

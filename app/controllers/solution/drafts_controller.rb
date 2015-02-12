class Solution::DraftsController < ApplicationController

	def index
		@drafts = current_account.solution_drafts.all(:include => {:article => {:folder => :category} })
	end

	def destroy
		draft = current_account.solution_drafts.find_by_id(params[:id])
		draft.discard_notification(current_portal)
		draft.destroy
    redirect_to :back
	end

	def delete_tag
		draft = current_account.solution_drafts.find_by_id(params[:draft_id])     
		tag = draft.tags.find_by_id(params[:id])
		raise ActiveRecord::RecordNotFound unless tag
		taggable_type = "Solution::Draft"
		Helpdesk::TagUse.find_by_taggable_id_and_taggable_type_and_tag_id(draft.id,taggable_type ,tag.id).destroy
		flash[:notice] = t(:'flash.solutions.remove_tag.success')
		redirect_to :back
	end

	def autosave
		draft = current_account.solution_drafts.find_by_id(params[:id])
		if (draft.present? && (draft.current_author == current_user) && draft.update_attributes(params[:draft_data]))
			render :text => "Success"
		else
			render :text => "Failure"
		end
	end
	
end
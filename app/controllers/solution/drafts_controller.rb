class Solution::DraftsController < ApplicationController

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
	before_filter :set_selected_tab, :only => [:index]
	before_filter :page_title, :only => [:index]

	# before_filter :load_article, :only => [:]

	def index
		@my_drafts = (params[:type] == 'my_drafts')
		scope = @my_drafts ? [:drafts_by_user, current_user] : [:all_drafts]
		@articles = current_account.solution_articles.send(*scope).paginate(:page => params[:page], :per_page => 10)
	end

	def destroy
		draft = current_account.solution_drafts.find_by_id(params[:id])
		draft.discard_notification(current_portal)
		draft.destroy
    redirect_to :back
	end

	def publish
		draft = current_account.solution_drafts.find_by_article_id(params[:id])
		if draft.present?
			draft.publish!
		else
			article = current_account.solution_articles.find_by_id(params[:id])
			article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
			article.save
		end
		flash[:success] = "The article was published successfully."
		redirect_to :back
	end

	def autosave
		@draft = current_account.solution_drafts.find_or_initialize_by_article_id(params[:id])
		p "#"*50, "All Params : #{params}"
		render :json => autosave_validate.to_json, :formats => [:js], :status => 200
	end

	def attachments_delete
		@article = current_account.solution_articles.find_by_id(params[:article_id])
		@draft = (@article.draft.present? ? @article.draft : @article.create_draft_from_article)
		delete_attachment
		p "#"*100, "Reached inside the delete attachments. Enjoy"
		respond_to do |format|
			format.js { after_destory_js }
		end
	end

	private

		def set_selected_tab
      @selected_tab = :solutions
    end     
    
    def page_title
      @page_title = t("header.tabs.solutions")    
    end

    def load_article
    	@article = current_account.solution_articles.find_by_id(params[:id])
    end

		def autosave_validate
			return autosave_content_validate if (@draft.current_author == current_user || @draft.current_author == nil || !@draft.locked?)
			{ :success => false, :msg => "Somebody is editing yaar." }
		end

		def autosave_content_validate
			if (@draft.new_record? || (!@draft.new_record? && (@draft.last_updated_timestamp == params[:timestamp].to_i)))
				if @draft.update_attributes(params.slice(*["description", "title"]))
					@draft.lock_for_editing! unless @draft.locked?
					return { :success => true, :timestamp => @draft.last_updated_timestamp, :msg => "Draft saved " }
				end
				return { :success => false, :msg => "Could not save due to some other reason. Please Reload." }
			end
			return { :success => false, :msg => "Content has changed. So please reload the page."}
		end

		def delete_attachment
			assoc = params[:attachment_type].pluralize.to_sym
			@att = @article.send(assoc).find(params[:attachment_id])
			if @draft.meta.present? && @draft.meta[:deleted_attachments].present? && @draft.meta[:deleted_attachments][assoc].present?
				@draft.meta[:deleted_attachments][assoc] += [@att.id]
			elsif @draft.meta.present? && @draft.meta[:deleted_attachments].present?
				@draft.meta[:deleted_attachments][assoc] = [@att.id]
			else
				@draft.meta = {}
				@draft.meta[:deleted_attachments] = {}
				@draft.meta[:deleted_attachments][assoc] = [@att.id]
			end
			@draft.save
		end

		def after_destory_js
			flash[:notice] = render_to_string(:partial => '/helpdesk/shared/flash/delete_notice').html_safe
			render(:update) { |page| 
				page.visual_effect('fade', dom_id(@att));
				show_ajax_flash(page)
			}
		end
	
end
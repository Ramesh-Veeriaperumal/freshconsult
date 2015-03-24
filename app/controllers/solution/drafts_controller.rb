class Solution::DraftsController < ApplicationController

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
	before_filter :set_selected_tab, :only => [:index]
	before_filter :page_title, :only => [:index]

	before_filter :load_article, :only => [:publish, :attachments_delete]
	before_filter :load_attachment, :only => [:attachments_delete]

	def index
		@articles = current_account.solution_articles.send(*scope).paginate(:page => params[:page], :per_page => 10)
	end

	def destroy
		draft = current_account.solution_drafts.find_by_id(params[:id])
		unless draft.locked?
			flash[:notice] = t('solution.articles.draft.discard_msg')
			draft.discarding = true
			draft.destroy
		end
    redirect_to :back
	end

	def publish
		redirect_to :back and return if @article.draft.present? && @article.draft.locked?
		@article.draft.present? ? @article.draft.publish! : @article.publish!
		redirect_to :back
	end

	def autosave
		@draft = current_account.solution_drafts.find_or_initialize_by_article_id(params[:id])
		render :json => autosave_validate.to_json, :formats => [:js], :status => 200
	end

	def attachments_delete
		@draft = (@article.draft.present? ? @article.draft : @article.create_draft_from_article)
		pseudo_delete_article_attachment
		respond_to do |format|
			format.js { flash[:notice] = t('solution.articles.att_deleted') }
		end
	end

	private

		def scope
			(params[:type] == 'my_drafts') ? [:drafts_by_user, current_user] : [:all_drafts]
		end

		def set_selected_tab
      @selected_tab = :solutions
    end     
    
    def page_title
      @page_title = t("header.tabs.solutions")    
    end

    def load_article
    	@article = current_account.solution_articles.find_by_id((params[:article_id] || params[:id]), :include => :draft)
    end

		def load_attachment
			@assoc = params[:attachment_type].pluralize.to_sym
			@attachment = @article.send(@assoc).find(params[:attachment_id])
		end

		def autosave_validate
			return autosave_content_validate if editable?
			autosave_response(:somebody_editing).merge({:msg => t('solution.draft.autosave.somebody_editing', :name => @draft.current_author.name)})
		end

		def editable?
			@draft.current_author == current_user || @draft.current_author == nil || !@draft.locked?
		end

		def autosave_content_validate
			content_changed? ? autosave_response(:content_changed) : autosave_save_draft
		end

		def content_changed?
			!@draft.new_record? && (@draft.updation_timestamp != params[:timestamp].to_i)
		end

		def autosave_save_draft
			if @draft.update_attributes(params.slice(*["description", "title"]))
				@draft.lock_for_editing! unless @draft.locked?
				return autosave_response(:save_success, true).merge({:timestamp => @draft.updation_timestamp})
			end
			autosave_response(:other_problem)
		end

		def autosave_response(key, success = false)
			{
				:success => success,
				:msg => t("solution.draft.autosave.#{key}")
			}
		end

		def pseudo_delete_article_attachment
			deleted = { @assoc => [@attachment.id]}
			@draft.meta[:deleted_attachments] ||= {}
			@draft.meta[:deleted_attachments].merge!(deleted) { |key,oldval,newval| oldval | newval }
			
			@draft.save
		end
	
end
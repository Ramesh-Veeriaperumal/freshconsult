class Freshfone::IvrsController < ApplicationController

	before_filter { |c| c.requires_feature :freshfone }
	before_filter :load_ivr, :only => [ :edit, :show, :update, :destroy, :activate, :deactivate ]
	before_filter :parse_relations, :build_attachments, :handle_draft_save, :only => :update
	# rescue_from Ancestry::AncestryException do |exception|
	# 	redirect_to :back, :alert => t(exception.message)
	# end

	def new
		@ivr = scoper.build(:parent_id => params[:parent_id])
	end

	def create
		@ivr = scoper.build(params[nscname])
		if @ivr.save!
			flash[:notice] = t(:'flash.general.update.success', :human_name => "IVR")
			redirect_to @ivr
		else
			flash[:notice] = t(:'flash.general.update.failure', :human_name => "IVR")
			render :action => :new
		end
	end

	def show
		@number = @ivr.freshfone_number
		redirect_to edit_admin_freshfone_number_path(@number)
	end

	def index
		@ivrs = scoper
    render :text => ' '
	end

	def edit
	end

	def update
		# send http status codes in json response
		if @ivr.update_attributes(params[nscname])
			remove_unused_attachments
			flash[:notice] = t(:'flash.general.update.success', :human_name => "IVR")

			respond_to do |format|
				format.html {
					redirect_to admin_freshfone_number_path(@ivr.freshfone_number_id)
				}
				format.json { render :json => { :status => :success } }
			end
		else
			respond_to do |format|
				format.html { 
					flash[:notice] = t(:'flash.general.update.failure', :human_name => "IVR")
					load_dependencies; render "admin/freshfone/numbers/edit"#  TODO-RAILS3 possible dead code by sath
				}
				format.json { render :json => { 
					:error_message => render_to_string(:partial => 'error_message') } }
			end
		end
	end

	def activate
		if @ivr.update_attributes({ :active => true })
			flash[:notice] = t(:'flash.general.activation.success', :human_name => "IVR")
		else
			flash[:notice] = t(:'flash.general.activation.failure', :human_name => "IVR")
		end

		respond_to { |format| format.js }
	end
	
	def deactivate
		if @ivr.update_attributes({ :active => false })
			flash[:notice] = t(:'flash.general.deactivation.success', :human_name => "IVR")
		else
			flash[:notice] = t(:'flash.general.deactivation.failure', :human_name => "IVR")
		end

		respond_to { |format| format.js }
	end

	def destroy
    @ivr.destroy
		if @ivr.destroyed?
			flash[:notice] = t(:'flash.general.destroy.success', :human_name => "IVR")
		else
			flash[:notice] = t(:'flash.general.destroy.failure', :human_name => "IVR")
		end
    redirect_to :action => :index
	end


	private
		def scoper
			current_account.ivrs
		end

		def nscname
			@nscname ||= controller_path.gsub('/', '_').singularize
		end

		def load_ivr
			@ivr = scoper.find(params[:id])
		end

		def parse_relations
			return if params[nscname]["relations"].blank?
			params[nscname]["relations"] = JSON.parse(params[nscname]["relations"])
		end

		def build_attachments
			@ivr.attachments_hash = build_attachments_hash
			params[nscname].reject!{ |k,v| k == "attachments"}
		end
		
		def build_attachments_hash
			(params[nscname][:attachments] || {}).inject({}) do |hash, (k, v)|
				hash[k] = @ivr.attachments.build(:content => v[:content],
					:description => v[:description], :account => current_account) unless v[:content].blank?
				hash
			end
		end

		def load_dependencies
			@number = @ivr.freshfone_number
			@agents = current_account.users.technicians
			@groups = current_account.groups
		end

		def remove_unused_attachments
			unused_attachments = @ivr.unused_attachments.map(&:id)
			Resque.enqueue(Freshfone::Jobs::AttachmentsDelete, { 
					:attachment_ids => unused_attachments 
				}) if unused_attachments.present?
		end
		
		def handle_draft_save
			preview = params[:preview] ? params[:preview].to_bool : false
			return unless preview
			@ivr.set_preview_mode
			params[nscname].delete(:message_type)
			params[nscname][:ivr_draft_data] = params[nscname].delete(:ivr_data)
		end

end

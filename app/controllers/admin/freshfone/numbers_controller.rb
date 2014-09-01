class Admin::Freshfone::NumbersController < Admin::AdminController
	before_filter(:only => [:purchase]) { |c| c.requires_feature :freshfone }
	before_filter :check_active_account, :only => :edit
	before_filter :load_number, :except => [ :index, :purchase ]
	before_filter :load_ivr, :only => :edit
	before_filter :build_attachments, :set_business_calendar,
							  :only => :update

	def index
		@numbers = current_account.freshfone_numbers
		@account = current_account.freshfone_account
	end

	def purchase
		begin
		if purchase_number.save
			flash[:notice] = t('flash.freshfone.number.success')
			redirect_to edit_admin_freshfone_number_path(@purchased_number)
		else
			flash[:notice] = (@purchased_number.errors.any?) ? 
												@purchased_number.errors.full_messages.to_sentence :
												t('flash.freshfone.number.error')
			redirect_to :action => :index
		end
		rescue Exception => e
			flash[:notice] = t('flash.freshfone.number.error')
			Rails.logger.debug "Error purchasing number for account#{current_account.id}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
			redirect_to :action => :index
		end
	end

	def show
		redirect_to edit_admin_freshfone_number_path(@number)
	end

	def update
		# send http status codes in json response
		if @number.update_attributes(params[nscname])
			remove_unused_attachments
			flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)

			respond_to do |format|
				format.html { redirect_to edit_admin_freshfone_number_path(@number) }
				format.json { render :json => { :status => :success } }
			end

		else
			flash[:notice] = t(:'flash.general.update.failure', :human_name => human_name)
			respond_to do |format|
				format.html { load_ivr; render :edit }
				format.json { render :json => { 
					:error_message => render_to_string(:partial => 'error_message') } }
			end
		end
	end

	def destroy
		if @number.update_attributes(:deleted => true)
			flash[:notice] = t(:'flash.general.destroy.success', :human_name => human_name)
		else
			flash[:notice] = t(:'flash.general.destroy.failure', :human_name => human_name)
		end
		redirect_to admin_freshfone_numbers_path
	end

	private
		def purchase_number
			@purchased_number = current_account.freshfone_numbers.new( 
				:number => params[:phone_number], 
				:display_number => params[:formatted_number], 
				:number_type => number_type,
				:region => params[:region], 
				:country => params[:country], 
				:address_required => params[:address_required])
		end

		def check_active_account
			if current_account.freshfone_credit.zero_balance?
				flash[:notice] = t('freshfone.general.suspended_on_low_balance')
				redirect_to admin_freshfone_numbers_path 
			elsif current_account.freshfone_account.suspended?
				flash[:notice] = t('freshfone.general.suspended_account')
				redirect_to admin_freshfone_numbers_path 	
			end
		end

		def load_number
			@number ||= current_account.freshfone_numbers.find_by_id(params[:id])
			redirect_to admin_freshfone_numbers_path if @number.blank?
		end

		def load_ivr
			@ivr = @number.ivr
			@agents = current_account.users.technicians.visible
			@groups =  current_account.active_groups
		end

		def set_business_calendar
			if params[:non_business_hour_calls].to_bool
				@number.business_calendar = nil
			else
				@number.business_calendar = business_calendar
			end
		end

		def business_calendar
			return current_account.business_calendar.find(params[:business_calendar]) if 
								current_account.features?(:multiple_business_hours) and params[:business_calendar]
			current_account.business_calendar.default.first
		end

		def build_attachments
			@number.attachments_hash = build_attachments_hash
			params[nscname].reject!{ |k,v| k == "attachments"}
		end
		
		def build_attachments_hash
			(params[nscname][:attachments] || {}).inject({}) do |hash, (k, v)|
				hash[k.to_sym] = @number.attachments.build( :content => v[:content], 
					:description => v[:description], :account => current_account) unless v[:content].blank?
				hash
			end
		end
		
		def remove_unused_attachments
			unused_attachments = @number.unused_attachments.map(&:id)
			Resque.enqueue(Freshfone::Jobs::AttachmentsDelete, { 
					:attachment_ids => unused_attachments 
				}) if unused_attachments.present?
		end

		def nscname
			@nscname ||= controller_path.gsub('/', '_').singularize
		end

		def human_name
			t('freshfone.number')
		end

		def number_type
			Freshfone::Number::TYPE_STR_HASH[params[:type]]
		end

end
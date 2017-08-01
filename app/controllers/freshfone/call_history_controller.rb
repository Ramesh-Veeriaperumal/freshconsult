class Freshfone::CallHistoryController < ApplicationController
	include Freshfone::CallHistory
	include Freshfone::FreshfoneUtil
	include Redis::RedisKeys
  include Redis::OthersRedis
  include Export::Util
	before_filter :set_native_mobile, :only => [:custom_search, :children]
	before_filter :cache_filter_params, :only => [:custom_search, :export]
	before_filter :load_cached_filters, :only => [:index, :export]
	before_filter :load_calls, :only => [:index, :custom_search]
	before_filter :load_children, :only => [:children]
	before_filter :fetch_recent_calls, :only => [:recent_calls]
	before_filter :fetch_blacklist, :only => [:index, :custom_search, :children]
	before_filter :check_export_range, :only => [:export]
	
	before_filter :fetch_current_call, :only =>[:destroy_recording], if: 'privilege?(:admin_tasks)'

	EXPORT_TYPE = "call_history"
	
	def index
		@all_freshfone_numbers = current_account.all_freshfone_numbers.order("deleted ASC").all
	end
	
	def custom_search
		respond_to do |format|
			format.js {}
            format.nmobile {
				response = {:calls => @calls.map(&:as_calls_mjson)}
				if params[:page] == "1"
					response.merge!(:freshfone_numbers => current_account.freshfone_numbers.map(&:as_numbers_mjson) ,
					 :group_numbers => current_account.freshfone_numbers.accessible_freshfone_numbers(current_user).map(&:as_numbers_mjson)) 
				end
				render :json => response
            }
		end
	end

	def children
		respond_to do |format|
			format.js {}
            format.nmobile {
            	response = {:calls => @calls.map(&:as_calls_mjson)}
                render :json => response
            }
		end
	end
	
	def recent_calls
		respond_to do |format|
			format.js {} 
		end
	end

	def destroy_recording
		if @call.present?
			begin
				flash[:notice] = @call.delete_recording(current_user.id) ? 
					t('freshfone.call_history.recording_delete.successful') : t('freshfone.call_history.recording_delete.unsuccessful')
			rescue Exception => e
				flash[:notice] = t('freshfone.call_history.recording_delete.error')
				Rails.logger.debug "Error deleting the recording for call #{@call.id} account #{current_account.id}
				.\n #{e.message} \n#{e.backtrace.join("\n\t")}"
			end
		end
	end

	def export
	check_and_create_export EXPORT_TYPE
    params.merge!({ :account_id => current_account.id, :user_id => current_user.id, :export_id => @data_export.id })
    Resque.enqueue(Freshfone::Jobs::CallHistoryExport::CallHistoryExport, params)
    render nothing: true
	end

	private
		
    def load_calls
			params[:wf_per_page] = 30
			@calls = all_numbers? ? 
                  current_account.freshfone_calls.roots.filter(:params => params,
						        :filter => "Freshfone::Filters::CallFilter") : 
                  current_number.freshfone_calls.roots.filter(:params => params,
						        :filter => "Freshfone::Filters::CallFilter")
      freshfone_stats_debug("all_number_option",params[:controller]) if all_numbers?
		end
        
        def all_numbers?
            params[:number_id] == Freshfone::Number::ALL_NUMBERS
        end    
        
        def current_number
			@current_number ||= params[:number_id].present? ? current_account.all_freshfone_numbers.find_by_id(params[:number_id])
                           : current_account.freshfone_numbers.first || current_account.all_freshfone_numbers.first 
		end
	
		def load_children
			#  remove include of number and use current_number instead
			@parent_call = all_numbers? ? current_account.freshfone_calls.find(params[:id]) : current_number.freshfone_calls.find(params[:id])
			@calls = @parent_call.descendants unless @parent_call.blank?
		end

		def calls_filter_key
			ADMIN_CALLS_FILTER % {:account_id => current_account.id, :user_id => current_user.id}
		end

		def cache_filter_params
			if !is_native_mobile?
				set_others_redis_hash(calls_filter_key, filter_hash)
				set_others_redis_expiry(calls_filter_key,86400*7)
			end
		end

		def filter_hash
			{:data_hash => params[:data_hash], :number_id => params[:number_id], :date_range_type => params[:date_range_type]}
		end

		def load_cached_filters
			 if redis_key_exists?(calls_filter_key)
					@cached_filters = get_others_redis_hash(calls_filter_key)
					prepare_filters(@cached_filters) if @cached_filters['data_hash'].present?
			 end
		end

		def fetch_recent_calls
			@calls = current_user.freshfone_calls.roots.newest(5).include_customer if current_user.agent?
		end

		def fetch_blacklist
			@blacklist_numbers =  current_account.freshfone_callers.blocked_callers.pluck(:id)
		end

		def check_export_range
			render nothing: true, status: 400 if !within_export_range?
		end

		def within_export_range?
			date_hash = JSON.parse(params[:data_hash]).find { |entry| entry["condition"] == "created_at" }
			return false if date_hash.blank?
			dates = date_hash["value"].split('-')
			return true if dates.count < 2
			days = dates.map { |d| Date.parse(d) }.reduce { |diff, date| date.mjd - diff.mjd }
			days < Freshfone::Call::EXPORT_RANGE_LIMIT_IN_MONTHS * 31
		end
		def fetch_current_call
			@call = current_call if params[:id].present?
		end
end

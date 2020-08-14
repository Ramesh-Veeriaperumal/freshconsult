module Helpdesk::SlaPoliciesHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant

	DEFAULT_SLA_SECONDS = 900 #Default time for sla - 15 minutes
	SECONDS_IN_MINUTE = 60
	SECONDS_IN_HOUR = 3600
	SECONDS_IN_DAY = 86400
	SECONDS_IN_MONTH = 2592000

  def response_time_options
    return Helpdesk::SlaDetail::response_time_options if !current_account.premium?
    Helpdesk::SlaDetail::premium_time_options + Helpdesk::SlaDetail::response_time_options
  end

  def resolution_time_options
  	return Helpdesk::SlaDetail::resolution_time_option if !current_account.premium?
    Helpdesk::SlaDetail::premium_time_options+ Helpdesk::SlaDetail::resolution_time_option
  end

  def escalation_time_options
    (current_account.premium? ? Helpdesk::SlaPolicy::esclation_premium_time_options :
    	Helpdesk::SlaPolicy::esclation_time_options)
  end

    def groups
      current_account.groups.map { |group| [group.name, group.id] if group.support_agent_group? }.compact
    end
    alias_method :group_id_list, :groups

	def products
		(current_account.products || {}).map{ |product| [product.name, product.id] }
	end
	alias_method :product_id_list, :products
	
	def sources
	  Helpdesk::Source.source_choices(:ticket_source_keys_by_token)
	end
	alias_method :source_list, :sources

    def ticket_types
      current_account.ticket_type_values.collect { |c| [ c.value, c.value ]  if c.value != SERVICE_TASK_TYPE }.compact
    end
    alias_method :ticket_type_list, :ticket_types

	def get_value seconds, select_field=false
		seconds = DEFAULT_SLA_SECONDS unless seconds.present?
		seconds = seconds.to_f # For enabling decimal division
		if !(seconds/SECONDS_IN_MONTH).zero? and (seconds/SECONDS_IN_MONTH) % 1 == 0
			return SECONDS_IN_MONTH if select_field
			return (seconds/SECONDS_IN_MONTH).to_i
		elsif !(seconds/SECONDS_IN_DAY).zero? and (seconds/SECONDS_IN_DAY) % 1 == 0
			return SECONDS_IN_DAY if select_field
			return (seconds/SECONDS_IN_DAY).to_i
		elsif !(seconds/SECONDS_IN_HOUR).zero? and (seconds/SECONDS_IN_HOUR) % 1 == 0
			return SECONDS_IN_HOUR if select_field
			return (seconds/SECONDS_IN_HOUR).to_i
		elsif !(seconds/SECONDS_IN_MINUTE).zero? and (seconds/SECONDS_IN_MINUTE) % 1 == 0
			return SECONDS_IN_MINUTE if select_field
			return (seconds/SECONDS_IN_MINUTE).to_i
			#really bad hack should not be done !
		elsif (seconds%SECONDS_IN_DAY) == 1 and seconds > SECONDS_IN_DAY
			return SECONDS_IN_HOUR if select_field
			return (seconds/SECONDS_IN_HOUR).to_i
		end
	end

	def sla_options
		Helpdesk::SlaDetail.sla_options
	end

	def reminder_time_options
   		Helpdesk::SlaPolicy::remainder_time_option
  	end

	# ITIL Related Methods starts here

	def form_partial(form_object)
		render(:partial => "form", :locals => { :f => form_object })
	end

	def success_feature_buttons
	end

	def failure_feature_buttons
	end

	# ITIL Related Methods ends here
end

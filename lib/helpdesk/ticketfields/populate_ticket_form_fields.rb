module Helpdesk::Ticketfields::PopulateTicketFormFields

	include Helpdesk::Ticketfields::TicketFormFields

	def form_fields_data(starting_account_id=0)
		Sharding.execute_on_all_shards do
			Account.current_pod.find_in_batches(:batch_size => 500,
				:conditions => "id >=#{starting_account_id}") do |accounts|
				accounts.each do |account|
					# Resque.enqueue(Workers::PopulateTicketFormFieldsWorker, {:account_id => account.id})
					populate_data(account)
				end
			end
		end
	end

	def populate_data(account)
		puts "===account==#{account.id}===#{account.name}"
		tkt_fields = account.ticket_fields
		begin
			tkt_fields.each do |tkt_field|
				save_form_field(tkt_field)
				puts "==updated field==#{tkt_field.label}"
				if(tkt_field.field_type == 'nested_field')
					tkt_field.nested_ticket_fields.each do |nested_field|
						save_form_nested_field(nested_field)
						puts "==updated nested field==#{nested_field.label}"
					end
				end
			end
		rescue => e 
			puts "######### Error while populating for Account=#{account.id}==#{account.name}"
		end
	end
	
end


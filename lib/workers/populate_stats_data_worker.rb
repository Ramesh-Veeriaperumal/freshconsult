module Workers
	module PopulateStatsDataWorker
		@queue = "reports_stats_data"

		class << self

			include Reports::TicketStats
			include Helpdesk::Ticketfields::TicketStatus

			def perform(args)
				args.symbolize_keys!
				gen_stats_data(args[:account_id],args[:start_time],args[:end_time])
			end

			def gen_stats_data(account_id, start_time, end_time)
				SeamlessDatabasePool.use_persistent_read_connection do
					account = Account.find_by_id(account_id)
					Time.zone = account.time_zone
					puts "Started at::::#{Time.zone.now}"
					account.tickets.find_in_batches(:batch_size => 1000, :include => :ticket_states, :conditions => 
					%(spam=false AND helpdesk_tickets.deleted=false AND status > 0 AND 
					helpdesk_tickets.created_at >= '#{Time.zone.parse(start_time.to_s).to_s(:db)}' AND 
					helpdesk_tickets.created_at <= '#{Time.zone.parse(end_time.to_s).to_s(:db)}')) do |tkt_arr|
						puts "batch Started at::::#{Time.zone.now}"
						tkt_arr.each do |tkt|
							tkt_state = tkt.ticket_states
							dates_hash = {:created_at => tkt.created_at.strftime("%Y-%m-%d"),
								:first_assigned_at => tkt_state.first_assigned_at.try(:strftime, "%Y-%m-%d"),
								:assigned_at => tkt_state.assigned_at.try(:strftime, "%Y-%m-%d"),
								:opened_at => tkt_state.opened_at.try(:strftime, "%Y-%m-%d")}

							# ticket received case
							created_date = dates_hash[:created_at]
							assigned_tkt, reassigns, reopens, created_hour, action_array = 0, 0, 0, tkt.created_at.hour, [:created_at]

							if created_date.eql?(dates_hash[:first_assigned_at])
								assigned_tkt = 1 
								action_array << :first_assigned_at
							end
							if created_date.eql?(dates_hash[:assigned_at]) && (tkt_state.first_assigned_at != tkt_state.assigned_at)
								reassigns = 1 
								action_array << :assigned_at
							end
							
							if (created_date.eql?(dates_hash[:opened_at]))
								reopens = 1
								action_array << :opened_at
							end
							stats_table_name = stats_table(Time.zone.parse(created_date), account)
							select_sql = %(SELECT * FROM #{stats_table_name} where ticket_id = #{tkt.id} and 
									account_id = #{account_id} and created_at = '#{created_date} 00:00:00')
							SeamlessDatabasePool.use_master_connection
							result = ActiveRecord::Base.connection.execute(select_sql)
							if result.num_rows == 0 # tkt received case
								sql = %(INSERT INTO #{stats_table_name} (#{REPORT_STATS.join(",")}) VALUES(#{account_id},#{tkt.id},
		          '#{created_date} 00:00:00','#{created_hour}', NULL,1,0,#{reopens},#{assigned_tkt},#{reassigns},0,0))
							else
								sql = %(UPDATE #{stats_table_name} SET created_hour = #{created_hour}, received_tickets = 1,
									num_of_reopens = #{reopens},assigned_tickets = #{assigned_tkt}, num_of_reassigns = #{reassigns} where 
									ticket_id = #{tkt.id} and account_id = #{account_id} and created_at = '#{created_date} 00:00:00')
							end
							begin
								ActiveRecord::Base.connection.execute(sql)
								SeamlessDatabasePool.use_persistent_read_connection
							rescue Exception => e
								puts "Record might already be exist in ticket received case:::#{e.message}"
								puts "account_id:::#{account_id}:::ticket_id:::#{tkt.id}:::date:::#{created_date}"
							end
							# ticket received case ends here

							incompleted_action_array = dates_hash.keys - action_array

							incompleted_action_array.each do |action|
								date_val = dates_hash[action]
								next unless (date_val and !date_val.eql?(created_date))
								reopens, assigned_tkt, reassigns, update_cols = 0, 0, 0, []
								if action.eql?(:first_assigned_at)
									assigned_tkt = 1
									update_cols << "assigned_tickets = 1"
								end

								if action.eql?(:assigned_at) && (tkt_state.first_assigned_at != tkt_state.assigned_at)
									reassigns = 1
									update_cols << "num_of_reassigns = 1"
								end

								if (action.eql?(:opened_at))
									reopens = 1
									update_cols << %(num_of_reopens = #{reopens})
								end

								stats_table_name = stats_table(Time.zone.parse(date_val), account)
								select_sql = %(SELECT * FROM #{stats_table_name} where ticket_id = #{tkt.id} and 
									account_id = #{account_id} and created_at = '#{date_val} 00:00:00')
								SeamlessDatabasePool.use_master_connection
								result = ActiveRecord::Base.connection.execute(select_sql)
								if result.num_rows == 0 # tkt received case
									query = %(INSERT INTO #{stats_table_name} (#{REPORT_STATS.join(",")}) VALUES(#{account_id},#{tkt.id},
		      '#{date_val} 00:00:00',NULL,NULL,0,0,#{reopens},#{assigned_tkt},#{reassigns},0,0))
								else
									next if update_cols.empty?
									query = %(UPDATE #{stats_table_name} SET #{update_cols.join(',')} where ticket_id = #{tkt.id} and 
		        				account_id = #{account_id} and created_at = '#{date_val} 00:00:00')
								end
								begin
									ActiveRecord::Base.connection.execute(query)
									SeamlessDatabasePool.use_persistent_read_connection
								rescue Exception => e
									puts "Record might already be exist::::#{e.message}"
									puts "account_id:::#{account_id}:::ticket_id:::#{tkt.id}:::date:::#{date_val}"
								end
							end
						end
						puts "batch end time:::#{Time.zone.now}"
					end
					gen_resolved_stats_data(account, start_time, end_time)
					puts "Final time::::#{Time.zone.now}"
				end
			end

			def gen_resolved_stats_data(account, start_time, end_time)
				account.tickets.find_in_batches(:batch_size => 1000, :joins  => 
					"INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
					helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",:include => :ticket_states, :conditions => 
					%(spam=false AND helpdesk_tickets.deleted=false AND status in (#{RESOLVED},#{CLOSED}) AND 
					helpdesk_ticket_states.resolved_at is NOT NULL AND 
					helpdesk_ticket_states.resolved_at >= '#{Time.zone.parse(start_time.to_s).to_s(:db)}' AND 
					helpdesk_ticket_states.resolved_at <= '#{Time.zone.parse(end_time.to_s).to_s(:db)}')) do |tkt_arr|
						puts "resolved batch Started at::::#{Time.zone.now}"
						tkt_arr.each do |tkt|
							tkt_state = tkt.ticket_states
							resolved_date = tkt_state.resolved_at.try(:strftime, "%Y-%m-%d")
							next if resolved_date.blank?
							fcr_tkt, sla_tkt = (tkt_state.inbound_count == 1) ? 1 : 0, (tkt.due_by >= tkt_state.resolved_at) ? 1 : 0 
							stats_table_name = stats_table(Time.zone.parse(resolved_date), account)
							select_sql = %(SELECT * FROM #{stats_table_name} where ticket_id = #{tkt.id} and 
									account_id = #{account.id} and created_at = '#{resolved_date} 00:00:00')
							SeamlessDatabasePool.use_master_connection
							result = ActiveRecord::Base.connection.execute(select_sql)
							if result.num_rows == 0 # tkt resolved on any other day case
								query = %(INSERT INTO #{stats_table_name} (#{REPORT_STATS.join(",")}) VALUES(#{account.id},#{tkt.id},
		    '#{resolved_date} 00:00:00',NULL,#{tkt_state.resolved_at.hour},0,1,0,0,0,#{fcr_tkt},#{sla_tkt}))
							else
								query = %(UPDATE #{stats_table_name} SET resolved_tickets = 1, resolved_hour = #{tkt_state.resolved_at.hour}, 
		      			fcr_tickets = #{fcr_tkt}, sla_tickets = #{sla_tkt} where ticket_id = #{tkt.id} and 
		      				account_id = #{account.id} and created_at = '#{resolved_date} 00:00:00')
							end
							begin
								ActiveRecord::Base.connection.execute(query)
								SeamlessDatabasePool.use_persistent_read_connection
							rescue Exception => e
								puts "Record might already be exist::::#{e.message}"
								puts "account_id:::#{account.id}:::ticket_id:::#{tkt.id}"
							end
						end
				end
				puts "resolved batch finished at::::#{Time.zone.now}"
			end


		end

	end
end

# account_id => account_id
# ticket_id => id
# created_at => created_at/resolved_at/opened_at/assigned_at
# created_hour => created_at
# resolved_hour => resolved_at
# received_tickets => created_at
# resolved_tickets => resolved_at
# num_of_reopens => 1 if opened_at
# assigned_tickets => 1 if assigned_at
# num_of_reassigns => 1 if assigned_at != first_assigned_at
# fcr_tickets => 1 if resolved && inbound_count == 1
# sla_tickets => 1 if resolved && due_by > resolved_at
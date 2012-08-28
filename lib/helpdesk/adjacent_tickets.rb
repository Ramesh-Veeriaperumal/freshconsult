module Helpdesk::AdjacentTickets
	include RedisKeys

	def set_adjacent_list
		clear_adjacent_data
		list_push(adjacent_list_redis_key, @items.collect { |ticket| ticket.display_id.to_s })
	end

	def find_adjacent(direction = :next)
		find_in_list(direction) || find_in_all(direction)
	end

	private

		SWITCHES = {
			:prev => {
				:sql_operator => "<", 
				:order => "DESC",
				:list_push => "left",
				:which_end => "last",
				:list_index_operator => '-'
			},
			:next => {
				:sql_operator => ">", 
				:order => "ASC",
				:list_push => "right",
				:which_end => "first",
				:list_index_operator => '+'
			}
		}

		NO_ADJACENT_TICKET_FLAG = -1

		def clear_adjacent_data
			remove_key(adjacent_list_redis_key)
			remove_key(adjacent_meta_key)
		end

		def find_in_all(direction)
			return nil if @item.deleted or @item.spam

			next_ticket = current_account.tickets.find(:first, 
				:conditions => ["id #{SWITCHES[direction][:sql_operator]} ? 
													AND deleted = 0 AND spam = 0 ", @item.id], 
				:order => "id #{SWITCHES[direction][:order]}")

			return next_ticket.nil? ? nil : next_ticket.display_id
		end

		def find_in_list(direction = :next)
			return nil if tickets_adjacents_list.blank?

			index = tickets_adjacents_list.index(@item.display_id.to_s)
			return nil if index.blank?

			new_index = index.send(SWITCHES[direction][:list_index_operator] , 1)
			return tickets_adjacents_list[new_index] if within_bounds?(new_index)

			find_in_adjacent_pages(direction)
		end

		def tickets_adjacents_list
			@tickets_adjacents_list ||= list_members(adjacent_list_redis_key)
		end

		def within_bounds?(index)
			index < tickets_adjacents_list.size and index >= 0
		end

		def find_in_adjacent_pages(direction)
			filter_params = criteria
			if filter_params
				return NO_ADJACENT_TICKET_FLAG if direction == :prev and (filter_params[:page].blank? or filter_params[:page] == 1)

				filter_params[:page] = new_page(filter_params,direction)
				filter_params[:without_pagination] = true

				tickets = current_account.tickets.permissible(current_user).filter(
					:params => filter_params, 
					:filter => 'Helpdesk::Filters::CustomTicketFilter') unless filter_params[:page] <= 0
				
				unless tickets.blank?
					adding_to_list = tickets.collect { |ticket| ticket.display_id.to_s }
					adding_to_list.reverse! unless direction == :next
					list_push(adjacent_list_redis_key,adding_to_list, (SWITCHES[direction][:list_push]))
					return tickets.send(SWITCHES[direction][:which_end]).display_id
				end
			end
			return NO_ADJACENT_TICKET_FLAG
		end

		def criteria
			@adjacent_tickets_criteria ||= begin
				filter_params = get_key(cached_filters_key)
				if filter_params
					filter_params = JSON.parse(filter_params) 
					filter_params.symbolize_keys!      

					@ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
					@ticket_filter = @ticket_filter.deserialize_from_params(filter_params)
					@ticket_filter.query_hash = JSON.parse(filter_params[:data_hash]) unless filter_params[:data_hash].blank?

				else
					unless cookies[:filter_name].blank?
						filter_params = { :filter_name => cookies[:filter_name] }
						#If this is a number, if so consider as custom view
						unless cookies[:filter_name].to_i.to_s != cookies[:filter_name]	
							@ticket_filter = current_account.ticket_filters.find_by_id(cookies[:filter_name])
							@ticket_filter.query_hash = @ticket_filter.data[:data_hash]
							filter_params.merge!(@ticket_filter.attributes["data"])
						end
					end
				end
				filter_params
			end
		end

		def new_page(filter_params, direction)
			end_page = get_key(adjacent_meta_key) || {}

			unless end_page.blank?
				end_page = JSON.parse(end_page).symbolize_keys
				current = end_page[direction]
			end

			current = send("new_page_" + direction.to_s , filter_params, current)

			end_page[direction] = current
			set_key(adjacent_meta_key, end_page.to_json, 1.day.to_i)
			current
		end

		def new_page_prev(filter_params,current)
			return filter_params[:page].to_i - 1 if current.blank?
			return 0 unless current > 1
			current - 1
		end

		def new_page_next(filter_params,current)
			return current + 1 unless current.blank?
			filter_params[:page].blank? ?  2 : (filter_params[:page].to_i + 1)
		end

		def adjacent_meta_key
			prepare_redis_key(HELPDESK_TICKET_ADJACENTS_META)
		end

		def adjacent_list_redis_key
			prepare_redis_key(HELPDESK_TICKET_ADJACENTS)
		end

		def cached_filters_key
			prepare_redis_key(HELPDESK_TICKET_FILTERS)
		end

		def prepare_redis_key(key)
			key % { :account_id => current_account.id, 
					:user_id => current_user.id, 
					:session_id => session.session_id }
		end

end
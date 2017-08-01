require 'connection_pool'
ConnectionPool.class_eval do
 
	#1. check whether block has to be passed to call quit command for the connection. Most proabbly we might have to pass it here. Numbered it in the sequence block has to be passed(As 1,2,3)
	def close_connection(conn)
	    last_conn = stack.last
		if last_conn.object_id == conn.object_id 
			# behaviour to check: Pop all connection in stack(not same as available stack) , then exception will be thrown when
			# checkin will be called for the same connection object again. We have to catch that exception and handle it in that case
			#pop single connection right now
			pop_connection 
			@available.push(conn) # to shutdown properly
			@available.shutdown_connection(conn)
		end

	end

	def available_connection_length
		@available.length
	end

	#can be used to check whether temporary connection has to be created
	# should return whether all the connections in the connection pools is occupied currently and we cannot allocate any more connections
	def is_full?
		@available.empty? && @available.queue_max_length == @available.queue_created_length
	end
	
end


ConnectionPool::TimedStack.class_eval do

	#returns the no of available connections
	def queue_length
	 	@que.length
	end

	#returns the maximum possible connection it can hold
	def queue_max_length
		@max
	end

	#returns the no of connections created currently
	def queue_created_length
		@created
	end

	#2. check whether block has to be passed to call quit command for the connection. Most proabbly we might have to pass it here
	def shutdown_connection(conn)
	    temp_stack = []

	    @mutex.synchronize do
	    	# signals the other threads that are waiting for a connection . Since an existing connection is getting closed, we can allow other threads waiting for a new connection to get connection 
	      	@resource.broadcast 

	      	remove_connection(conn)
	    end
  	end

  	private

  	#should be called only from shutdown_Connection
  	#3. check whether block has to be passed to call quit command for the connection. Most proabbly we might have to pass it here
  	def remove_connection(conn_to_be_removed)
  		temp_stack = []
  		connection_to_be_deleted = nil
  		while connection_stored?
	      conn = fetch_connection
	      if conn.object_id == conn_to_be_removed.object_id
	      	connection_to_be_deleted = conn
	      	break 
	      end
	      temp_stack.push(conn)
	    end

	    if connection_to_be_deleted.present?
	    	@created = @created - 1 
	    	#should call quit command here if block has to be passed
	    end

	    while(temp_stack.length != 0)
	    	@que.push(temp_stack.pop)
	    end
  	end
end
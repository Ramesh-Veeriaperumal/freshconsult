module Helpdesk
	module DBStore
		class MailDBStore

			def fetch(key_path)
				return NotImplementedError,"Fetch is an abstract method"
			end

			def delete(key_path)
				return NotImplementedError,"delete is an abstract method"
			end

			def save(content, options={})
				return NotImplementedError,"save is an abstract method"
			end

			def delete_batch(key_paths)
				return NotImplementedError,"delete_batch is an abstract method"
			end

			def list_object(prefix)
				return NotImplementedError,"list_object is an abstract method"
			end
		end
	end
end
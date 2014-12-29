module Dynamo::Callbacks

	CALLBACKS = { "save" => ["before", "after"],
							"update" => ["before", "after"],
							"destroy" => ["before", "after"] }

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods

		CALLBACKS.each do |method, time_of_execution|
			time_of_execution.each do |prefix|
				define_method(%{#{prefix}_#{method}}) do |*callbacks|
					existing = self.instance_variable_get(%{@#{prefix}_#{method}_callbacks})
					instance_variable_set(%{@#{prefix}_#{method}_callbacks}, (existing || []) + callbacks)
					create_pseudo_method(method.to_sym)
				end
			end
		end

		def create_pseudo_method(method)
			@created_for ||= []
			return if @created_for.include?(method)
			alias_method "#{method}_without_callbacks", method

			define_method method do
				self.callback(:before, method)
				return_value = send "#{method}_without_callbacks"
				self.callback(:after, method) if return_value
				return_value
			end

			@created_for << method
		end
	end

	protected

		def callback(what = :after, action = :save)
			return true unless [:before, :after].include?(what) && [:update, :save, :destroy].include?(action)
			(self.class.instance_variable_get("@#{what}_#{action}_callbacks") || []).each do |meth|
				send(meth) if respond_to?(meth)
			end
		end
end
# TODO-RAILS3 Can be removed once we migrate fully.
module MailerDeliverAlias
  def self.included(base)
    base.instance_methods(false).each do |method_name|
      base.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def deliver_#{method_name}(*args)
          #{method_name}(*args)
        end
      RUBY_EVAL
    end
  end
end
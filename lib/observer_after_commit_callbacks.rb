require 'observer_callbacks'
module ObserverAfterCommitCallbacks
  def self.included(base)
    base.send(:extend, ObserverCallbacks) unless base.respond_to?(:define_model_callbacks_for_observers)
 
    [:create, :update, :destroy].each do |action|
      base.send(:define_model_callbacks_for_observers, :"commit_on_#{action}", :only => :after)
    end
 
    base.send(:attr_accessor, :newly_created)
    base.send(:before_validation, ObserverAfterCommitCallbacks::Handlers)
    base.send(:after_commit, ObserverAfterCommitCallbacks::Handlers)
  end
 
  module Handlers
    def self.before_validation(record)
      record.newly_created = record.new_record?
 
      true
    end
 
    def self.after_commit(record)
      action = record.destroyed? ? "destroy" : (record.newly_created ? "create" : "update")
 
      record.run_callbacks :"commit_on_#{action}"
 
      true
    rescue Exception => ex
      p ex
      raise ex
    end
  end
end
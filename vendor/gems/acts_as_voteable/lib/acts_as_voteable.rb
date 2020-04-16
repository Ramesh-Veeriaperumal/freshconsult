require "acts_as_voteable/engine"

# ActsAsVoteable
module Juixe
  module Acts #:nodoc:
    module Voteable #:nodoc:

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_voteable
          has_many :votes, :as => :voteable, :dependent => :destroy, :order => "id DESC"
          has_many :voters, :through => :votes, :source => :user, :order => "#{Vote.table_name}.id DESC"
          include Juixe::Acts::Voteable::InstanceMethods
          extend Juixe::Acts::Voteable::SingletonMethods
        end
      end
      
      # This module contains class methods
      module SingletonMethods
        def find_votes_cast_by_user(user)
          voteable = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
          Vote.where(['user_id = ? and voteable_type = ?', user.id, voteable]).order('created_at DESC').to_a
        end
      end
      
      # This module contains instance methods
      module InstanceMethods
        def votes_for
          votes = Vote.where([
            'voteable_id = ? AND voteable_type = ? AND vote = ?',
            id, self.class.name,true
          ]).to_a
          votes.size
        end
        
        def votes_against
          votes = Vote.where([
            'voteable_id = ? AND voteable_type = ? AND vote = ?',
            id, self.class.name, false
          ]).to_a
          votes.size
        end
        
        # Same as voteable.votes.size
        def votes_count
          self.votes.size
        end
        
        def users_who_voted
          users = []
          self.votes.each { |v|
            users << v.user
          }
          users
        end
        
        def voted_by_user?(user)
          rtn = false
          if user
            self.votes.each { |v|
              rtn = true if user.id == v.user_id
            }
          end
          rtn
        end
      end
    end
  end
end

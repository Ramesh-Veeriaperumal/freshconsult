module SBRR
  module Queue
    class Base

      include Redis::RedisKeys
      include Redis::RoundRobinRedis

      MAX_RETRIES = 10

      attr_accessor :account_id, :group_id, :skill_id, 
                    :object, :operation, :score_calculator, :old_score

      def initialize account_id, group_id, skill_id=nil, _score_calculator=nil
        @account_id       = account_id
        @group_id         = group_id
        @skill_id         = skill_id
        @score_calculator = _score_calculator
      end

      def top
        zrange_round_robin_redis(key, 0, 0, true).first
      end

      def all
        zrange_round_robin_redis(key, 0, -1)
      end

      def enqueue_object_with_lock _object
        @object = _object
        push_to_redis :zadd_multi_exec, __method__
      end

      def refresh_object_with_lock _object, score = nil
        @object = _object
        @old_score = score || zscore
        push_to_redis :zadd_multi_exec, __method__
      end

      def dequeue_object_with_lock _object
        @object = _object
        push_to_redis :zrem_multi_exec, __method__
      end

      def increment_object_with_lock _object
        check_and_set _object, :incr
        SBRR.log "In #{key} : Incrementing User : #{member} Score : #{"%016d" % score.to_i}"
      end

      def decrement_object_with_lock _object
        check_and_set _object, :decr
        SBRR.log "In #{key} : Decrementing User : #{member} Score : #{"%016d" % score.to_i}"
      end
      
      def check_and_set _object, _operation
        @object    = _object
        @operation = _operation
        MAX_RETRIES.times do
          watch
          @old_score = zscore
          result     = zadd_multi_exec
          return true if result.is_a?(Array) && result[1].present?
        end
        SBRR.log "check_and_set fail #{@object} #{@operation}"
        nil
      end

      def check_and_set_via_multi m, _object, _old_score, _operation
        @object    = _object
        @operation = _operation
        @old_score = _old_score
        zadd_via_multi m
      end

      def zscore _member=member
        zscore_round_robin_redis key, _member
      end

      def == q
        key == q.key
      end

      def set_via_multi m 
        m.set lock_key, lock_key_value
      end

      private

        def watch
          watch_round_robin_redis lock_key
        end

        def zadd_multi_exec
          result = $redis_round_robin.multi do |m|
            zadd_via_multi m
            set_via_multi m
          end
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          SBRR.log "zadd_multi_exec exception #{e.message}"
          return
        end

        def zrem_multi_exec
          $redis_round_robin.multi do |m|
            zrem_via_multi m
            del_via_multi m
          end
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          SBRR.log "zrem_multi_exec exception #{e.message}"
          return
        end

        def zadd_via_multi m
          m.zadd key, score, member
        end

        def zrem_via_multi m
          m.zrem key, member
        end

        def del_via_multi m
          m.del lock_key
        end

        def valid_queue?
          account_id && group_id && skill_id
        end

        def member
          @object_id || @object.id
        end

        def score
          @score ||= score_calculator.score object
        end

        def lock_key_value
          score
        end

        def push_to_redis method, source
          SBRR.log "#{source} #{member} to #{key} with score #{@old_score}"
          MAX_RETRIES.times do
            result = safe_send(method)
            return true if result.is_a?(Array) && result[1].present?
          end
          SBRR.log "#{source} fail #{member} to #{key}"
          nil
        end

    end
  end
end

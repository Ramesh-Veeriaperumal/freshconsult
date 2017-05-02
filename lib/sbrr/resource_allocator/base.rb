module SBRR
  module ResourceAllocator
    class Base

      attr_accessor :user, :options

      def initialize(_user = nil, _options = {})
        @user = _user
        @options = _options
      end

      def allocate
        queues.each do |queue|
          loop do
            begin
              item_id, score = pop_from_queue queue
              break if item_id.nil?
              item = get_item item_id
              SBRR.log "popped #{item_id} with score #{score}"
              if item.present?
                is_assigned = assign_resource item

                unless is_assigned[:do_assign]
                  if is_assigned[:can_assign]
                    resync_to_queue item, score
                    break
                  end
                end
              end
            rescue => e
              SBRR.log "[#{self.class}] Allocating resource to item #{item_id} has thrown exception,#{e.message}, #{e.backtrace}"
              resync_to_queue(item)
            end
          end
        end
      end

      private
        def queues
          queue_aggregator.relevant_queues
        end

        def resync_to_queue(item, score)
          sbrr_queue_synchronizer(item).refresh(score)
        end

    end
  end
end

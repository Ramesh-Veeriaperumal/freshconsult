module Middleware
  module Sidekiq
    module Server
      class RouteORDrop
        include Redis::RedisKeys
        include Redis::OthersRedis

        def call(worker, payload, _queue)
          unless payload['reroute']
            worker_name                              = worker.class.to_s
            account_id                               = payload['account_id']
            account_route_or_drop, all_route_or_drop = fetch_route_or_drop_values(account_id, payload, worker_name)
            route_or_drop                            = account_route_or_drop || all_route_or_drop
            return if route_or_drop?(route_or_drop, worker_name, payload, account_id)

          end
          yield
        end

        private

          def route_or_drop?(route_or_drop, worker_name, payload, account_id)
            if route_or_drop
              if route_or_drop == 'drop'
                Rails.logger.info "Dropping worker: #{worker_name}, account_id: #{account_id}, payload: #{payload.inspect}"
                true
              elsif route_or_drop.ends_with?('_queue')
                payload['rerouted_queue'] = route_or_drop
                Rails.logger.info "Rerouting worker #{worker_name} account_id: #{account_id} payload: #{payload.inspect} rerouting: #{route_or_drop}"
                ::Sidekiq::Client.push(payload)
                true
              else
                Rails.logger.info "Route or drop key present but value is not valid #{worker_name} account_id: #{account_id} payload: #{payload.inspect} rerouting: #{route_or_drop}"
                false
              end
            else
              false
            end
          rescue StandardError => exception
            Rails.logger.error "Error while fetching drop or reroute: #{worker_name}, account_id: #{account_id}, payload: #{payload.inspect}"
            Rails.logger.error "Error message: #{exception.message}, #{exception.backtrace.join("\n\t")}"
            false
          end

          def account_worker_key(account_id, worker_name)
            format(BG_ACCOUNT_WORKER, account_id: account_id, worker: worker_name)
          end

          def fetch_route_or_drop_values(account_id, payload, worker_name)
            account_route_or_drop = nil
            all_route_or_drop     = nil
            begin
              account_route_or_drop, all_route_or_drop = get_multiple_redis_keys(account_worker_key(account_id, worker_name),
                                                                                 account_worker_key('all', worker_name)) || []
            rescue StandardError => exception
              Rails.logger.error "Error while fetching drop or reroute: #{worker_name}, account_id: #{account_id}, payload: #{payload}"
              Rails.logger.error "Error message: #{exception.message}, #{exception.backtrace.join("\n\t")}"
            end
            [account_route_or_drop, all_route_or_drop]
          end
      end
    end
  end
end

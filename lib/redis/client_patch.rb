######################################################################
# + This patch is for enabling password on the fly for redis +       #
#                                                                    #
# While enabling password on a redis server, the existing client     #
#   will catch AUTH exceptions and retry the request with password   #
#                                                                    #
# Subsequent calls from that connection would then succeed.          #
#                                                                    #
# If it gets reverted and then there is no password on the server    #
#   this patch would be able to connect back without password        #
#                                                                    #
# + Patch won't be required once the old connections are drained +   #
######################################################################
module Redis::ClientPatch
  Redis::Client.class_eval do
    AUTH_SUCCESS_MSG = '+OK'.freeze
    NOAUTH_MSG = 'NOAUTH Authentication required.'.freeze
    CLIENT_AUTH_MSG = 'ERR Client sent AUTH, but no password is set'.freeze

    def process(commands)
      res = block_given? ? process_override(commands) { yield } : process_override(commands)
      if res.is_a?(Redis::CommandError)
        if res.message == NOAUTH_MSG
          Rails.logger.warn 'Redis error :: Redis::CommandError'
          block_given? ? retry_with_password(commands) { yield } : retry_with_password(commands)
        # elsif res.message == CLIENT_AUTH_MSG
        #   return auth_success if commands[0][0] == :auth
        #   block_given? ? retry_wo_password(commands) { yield } : retry_wo_password(commands)
        else
          res
        end
      else
        res
      end
    rescue Redis::CannotConnectError
      Rails.logger.warn 'Redis error :: Redis::CannotConnectError'
      block_given? ? retry_with_password(commands) { yield } : retry_with_password(commands)
    end

    private

      def process_override(commands)
        logging(commands) do
          ensure_connected do
            commands.each do |command|
              if command_map[command.first]
                command = command.dup
                command[0] = command_map[command.first]
              end

              write(command)
            end
            yield if block_given?
          end
        end
      end

      def retry_with_password(commands)
        @pwd_retry_cnt = defined?(@pwd_retry_cnt) ? @pwd_retry_cnt + 1 : 1
        Rails.logger.warn "Retrying with password :: #{@pwd_retry_cnt}"
        return retries_exhausted_error("#{NOAUTH_MSG} :: exhausted retries", '@pwd_retry_cnt') if @pwd_retry_cnt > 1

        reconnect_with_opts if @pwd_retry_cnt == 1
        process(commands) { yield }
      end

      def reconnect_with_opts
        retry_options = { password: options[:retry_password] }
        retry_options[:port] = options[:retry_port] if options[:retry_port]
        retry_options[:host] = options[:retry_host] if options[:retry_host]
        instance_variable_set(:'@options', options.merge(retry_options))
        @connector.instance_variable_set(:'@options', @connector.instance_variable_get(:'@options').merge(retry_options))
        reconnect_with_retry(0)
      end

      def reconnect_with_retry(count)
        Rails.logger.warn "Reconnecting redis :: #{count}"
        reconnect
      rescue Redis::CannotConnectError => e
        sleep 0.2
        count += 1
        raise e if count > 1 || !e.message.include?('Errno::ECONNREFUSED')
        reconnect_with_retry(count)
      end

      def retries_exhausted_error(msg, var)
        remove_instance_variable var
        Redis::CommandError.new(msg)
      end

      def auth_success
        instance_variable_set(:'@options', options.except(:password))
        # @connector.instance_variable_set(:'@options', @connector.instance_variable_get(:'@options').merge(port: 6380))
        AUTH_SUCCESS_MSG
      end

      def retry_wo_password(commands)
        @pwdls_retry_cnt = defined?(@pwdls_retry_cnt) ? @pwdls_retry_cnt + 1 : 1
        return retries_exhausted_error("#{CLIENT_AUTH_MSG} :: exhausted retries", '@pwdls_retry_cnt') if @pwdls_retry_cnt > 2

        disconnect_with_opts if @pwdls_retry_cnt == 1
        process(commands) { yield }
      end

      def disconnect_with_opts
        disconnect_opts = options[:curr_port] ? { port: options[:curr_port] } : {}
        instance_variable_set(:'@options', options.except(:password).merge(disconnect_opts))
        @connector.instance_variable_set(:'@options', @connector.instance_variable_get(:'@options').merge(disconnect_opts))
        disconnect
      end
  end
end

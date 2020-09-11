require 'spam_watcher/spam_watcher_redis_methods'
module Helpdesk
	module Email
		# handles the requsts of incoming emails from email service and creates ticket/note.
		class IncomingEmailHandler < Struct.new(:params)
			include Redis::OthersRedis
			include Redis::RedisKeys
			include EnvelopeParser
			include Helpdesk::Email::Constants
			include AccountConstants
			include EmailHelper
			include Helpdesk::ProcessByMessageId
			include ParserUtil
			include EmailCommands
			include Helpdesk::DetectDuplicateEmail
			include ActionView::Helpers::TagHelper
			include ActionView::Helpers::TextHelper
			include ActionView::Helpers::UrlHelper
			include WhiteListHelper
			include Helpdesk::ProcessAgentForwardedEmail
			include Helpdesk::Utils::ManageCcEmails
			include Helpdesk::Permission::Ticket
			include Helpdesk::EmailParser::Constants
			include Helpdesk::Email::NoteMethods
			include Helpdesk::LanguageDetection
			include ::Email::AntiSpoof
            include ::Email::PerformUtil

			class UserCreationError < StandardError
			end

			class ShardMappingError < StandardError
			end
			LARGE_TEXT_TIMEOUT = 60

			attr_accessor :additional_emails, :archived_ticket, :start_time, :actual_archive_ticket
			def email_spam_watcher_counter(account)
				key = "sw_email_activities"
				max_count = 50
				sec_expire = 7200
			    begin
			      Timeout::timeout(SpamConstants::SPAM_TIMEOUT) {
			        user_id = ""
			        account_id = account.id
			        final_key = key + ":" + account_id.to_s + ":" + user_id.to_s
			        # this case is added for the sake of skipping imports
			        return true if ((Time.now.to_i - account.created_at.to_i) > 1.day)
			        return true if $spam_watcher.perform_redis_op("get", account_id.to_s + "-" + user_id.to_s)
			        count = $spam_watcher.perform_redis_op("rpush", final_key, Time.now.to_i)
			        $spam_watcher.perform_redis_op("expire", final_key, sec_expire+1.minute)
			        if count >= max_count

			          head = $spam_watcher.perform_redis_op("lpop", final_key).to_i
			          time_diff = Time.now.to_i - head
			          if time_diff <= sec_expire
			            SpamWatcherRedisMethods.incoming_email_spam(account)
			          end
			        end
			      }
			    rescue Exception => e
			      puts e
			      Rails.logger.error e.backtrace
			      NewRelic::Agent.notice_error(e,{:description => "error occured in updating spam_watcher_counter"})
			    end
			end

			def perform(parsed_to_email = Hash.new, skip_encoding = false)
		        if collab_email_reply? params[:subject]
		          # block all email related to collab based on subject
		          return processed_email_data(PROCESSED_EMAIL_STATUS[:noop_collab_email_reply])
		        end
		        result = {}
		        email_processing_log("Email received: Message-Id #{message_id}")
		        self.start_time = Time.now.utc
		        to_email = parsed_to_email.present? ? parsed_to_email : parse_to_email
		        shardmapping = ShardMapping.fetch_by_domain(to_email[:domain])
		        unless shardmapping.present?
		          email_processing_log("Email Processing Failed: No Shard Mapping found!")
		          return processed_email_data(PROCESSED_EMAIL_STATUS[:shard_mapping_failed])
		        end
		        unless shardmapping.ok?
		          if shardmapping.status == MAINTENANCE_STATUS
		            email_processing_log("Email Processing Failed: Account in maintenance")
		            raise ShardMappingError("Account in maintenance")
		          else
		            email_processing_log("Email Processing Failed: invalid shard mapping status")
		            return processed_email_data(PROCESSED_EMAIL_STATUS[:inactive_account])
		          end
		        end
		        Account.reset_current_account
		        Portal.reset_current_portal
		        Sharding.select_shard_of(to_email[:domain]) do
		          account = Account.find_by_full_domain(to_email[:domain])
		          if account && account.allow_incoming_emails?
		            account.make_current
		            email_spam_watcher_counter(account)
		            TimeZone.set_time_zone
		            from_email = parse_from_email(account)
		            if from_email.nil?
		              email_processing_log("Email Processing Failed: No From Email found!", to_email[:email])
		              return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_from_email], account.id)
		            end
		            if account.features?(:domain_restricted_access)
		              domain = (/@(.+)/).match(from_email[:email]).to_a[1]
		              wl_domain  = account.account_additional_settings_from_cache.additional_settings[:whitelisted_domain]
		              unless Array.wrap(wl_domain).include?(domain)
		                email_processing_log "Email Processing Failed: Not a White listed Domain!", to_email[:email]
		                return processed_email_data(PROCESSED_EMAIL_STATUS[:restricted_domain_access], account.id)
		              end
		            end
		            kbase_email = account.kbase_email
		            if (to_email[:email] != kbase_email)
		              email_config = account.email_configs.find_by_to_email(to_email[:email])
		              if email_config && (!params[:migration_enable_outgoing]) && (from_email[:email].to_s.downcase == email_config.reply_email.to_s.downcase)
		                email_processing_log "Email Processing Failed: From-email and reply-email are same!", to_email[:email]
		                return processed_email_data(PROCESSED_EMAIL_STATUS[:self_email], account.id)
		              end
		              if duplicate_email?(from_email[:email], to_email[:email], params[:subject], message_id)
		                return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], account.id)
		              end
		              if (from_email[:email] =~ EMAIL_VALIDATOR).nil?
		                envelope_from_email = parse_email JSON.parse(params[:envelope])["from"]
		                if (envelope_from_email[:email] =~ EMAIL_VALIDATOR).nil?
		                  error_msg = "Invalid email address found in requester details - #{from_email[:email]} for account - #{account.id}"
		                  Rails.logger.debug error_msg
		                  return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_from_email], account.id)
		                else
		                  from_email = envelope_from_email
		                end
		              end
		              # check for wildcards
		              wc_check_result = check_for_wildcard(email_config, account, to_email)
		              return wc_check_result[:message] if wc_check_result[:status]

		              user = existing_user(account, from_email)
		              unless user
		                text_part
		                user = create_new_user(account, from_email, email_config)
		              else
		                if user.blocked?
		                  email_processing_log "Email Processing Failed: User is been blocked!", to_email[:email]
		                  return processed_email_data(PROCESSED_EMAIL_STATUS[:user_blocked], account.id)
		                end
		                text_part
		              end
		              if (user.blank? && (account.sane_restricted_helpdesk_enabled? || !account.restricted_helpdesk?))
		                email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
		                return processed_email_data(PROCESSED_EMAIL_STATUS[:blank_user], account.id)
		              end
		              set_current_user(user)
		              if(params[:sanitize_done].nil? or params[:sanitize_done].to_s.downcase == "false")
		                self.class.trace_execution_scoped(['Custom/Helpdesk::IncomingEmailHandler/sanitize']) do
		                # Workaround for params[:html] containing empty tags
		                  if params[:html].blank? && !params[:text].blank? 
		                    email_cmds_regex = get_email_cmd_regex(account) 
		                    params[:html] = body_html_with_formatting(params[:text],email_cmds_regex) 
		                  end
		                end
		              end
		              result = add_to_or_create_ticket(account, from_email, to_email, user, email_config)
		            end
		            begin
		              if kbase_email_present?(kbase_email)
		                result = create_article(account, from_email, to_email)
		              end
		            rescue Exception => e
		              NewRelic::Agent.notice_error(e)
		            ensure
		              Account.reset_current_account
		            end
		          else
		            email_processing_log "Email Processing Failed: No active Account found!"
		            Rails.logger.info "Email Processing Failed: No active Account found!"
		            if account.nil?
		              Rails.logger.info "Email Processing Failed: Account is nil"
		              return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_account])
		            elsif !account.active?
		              Rails.logger.info "Email Processing Failed: Account is not active"
		              return processed_email_data(PROCESSED_EMAIL_STATUS[:inactive_account], account.id)
		            else
		              Rails.logger.info "Email Processing Failed: Invalid Account"
		              return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_account])
		            end
		          end
		        end
		        elapsed_time = (Time.now.utc - start_time).round(3)
		        Rails.logger.info "Time taken for incoming_email_handler perform : #{elapsed_time} seconds"
		        result
      end

			def parse_to_email
				envelope = params[:envelope]
				unless envelope.nil?
					envelope_to = (ActiveSupport::JSON.decode envelope)['to']
					return parse_email envelope_to.first unless (envelope_to.nil? || envelope_to.empty?)
				end

				parse_email params[:to]
			end
			def parse_email(email_text)
				parsed_email = parse_email_text(email_text)

				name = parsed_email[:name]
				email = parsed_email[:email]

				if(email && (email =~ EMAIL_REGEX))
					email = $1
				elsif(email_text =~ EMAIL_REGEX) 
					email = $1  
				end

				name ||= ""
				domain = (/@(.+)/).match(email).to_a[1]

				{:name => name, :email => email, :domain => domain}
			end
			def parse_from_email account
				f_email = parse_email(params[:from])
				reply_to_email = parse_email(params[:reply_to])
				reply_to_feature = account.features?(:reply_to_based_tickets)
				if reply_to_feature or invalid_from_email?(f_email, reply_to_email, reply_to_feature)
					return (reply_to_email[:email].nil? ? f_email : reply_to_email)
				else
					return f_email
				end
			end
			def invalid_from_email? f_email, reply_to_email, reply_to_feature
				(f_email[:email] =~ /(noreply)|(no-reply)/i or f_email[:email].blank?) and !reply_to_feature and !reply_to_email[:email].blank?
			end
			def processed_email_data(processed_status, account_id = -1, model = nil)
				data = { :account_id => account_id, :processed_status => processed_status }
				if processed_status == PROCESSED_EMAIL_STATUS[:success] && model.present?
					if model.class.name.include?("Ticket")
						data.merge!(:ticket_id => model.id, :type => PROCESSED_EMAIL_TYPE[:ticket], :note_id => "-1", :article_id => "-1", :display_id => model.display_id) # check with nil values
					elsif model.class.name.include?("Note")
						data.merge!(:ticket_id => model.notable_id, :note_id => model.id, :type => PROCESSED_EMAIL_TYPE[:note], :article_id => "-1")
						data.merge!(:display_id => model.notable.display_id) unless model.notable.nil?
					elsif model.class.name.include?("Article")
						data.merge!(:article_id => model.id, :type => PROCESSED_EMAIL_TYPE[:article], :ticket_id => "-1", :note_id => "-1")
					end
				end
				data.merge!(:message_id => message_id) if (account_id == -1)
				data.with_indifferent_access 
			end
			def kbase_email_present? kbase_email
				return false if auto_generated?(params[:headers])
				envelope = params[:envelope]
				return false if envelope.blank?
				envelope_to = (ActiveSupport::JSON.decode envelope)['to']
				return false if envelope_to.blank?
				envelope_to.map {|to_email| parse_email(to_email)[:email]}.include?(kbase_email) 
			end
			def existing_user(account, from_email)
				account.user_emails.user_for_email(from_email[:email])
			end
			def text_part
				begin
					Timeout.timeout(LARGE_TEXT_TIMEOUT) do
						if(params[:text].nil? || params[:text].empty?) 
							if params[:html].size < MAXIMUM_CONTENT_LIMIT
								params[:text] = Helpdesk::HTMLSanitizer.html_to_plain_text(params[:html])
							else
								email_processing_log "Large Email deducted . Content exceeding maximum content limit #{MAXIMUM_CONTENT_LIMIT} . "
								params[:text] = Helpdesk::HTMLSanitizer.html_to_plain_text(truncate(params[:html], :length => MAXIMUM_CONTENT_LIMIT))
							end
						end
					end
					return params[:text]
				rescue SystemStackError => e
					result = handle_system_stack_error e
					return result
				rescue => e
					Rails.logger.info "Exception while getting text_part , message :#{e.message} - #{e.backtrace}"
				end
				params[:text] = ""
			end

			def handle_system_stack_error e
				Rails.logger.info "Error during html sanitize : #{e.message}, #{e.backtrace}"
				account = Account.current
				email_cmds_regex = get_email_cmd_regex(account) 
				result = ((params[:text].nil? || params[:text].empty?) ? "" : body_html_with_formatting(params[:text],email_cmds_regex)) 
				result = "<br><p style=\"color:#FF2625;\"><b> *** Warning: This email might have some content missing. Please open the attached file original_email.html to see the entire message. *** </b></p><br>" + result
				original_email_content = StringIO.new(params[:html])
				original_email_content.class.class_eval { attr_accessor :original_filename, :content_type }
				original_email_content.content_type = "text/html"
				original_email_content.original_filename = "original_email.html"
				params[:attachments] = params[:attachments] + 1
				params["attachment#{params[:attachments]}"] = original_email_content
				result
			end

			def body_html_with_formatting(body,email_cmds_regex)
				body = body.gsub(email_cmds_regex,'<notextile>\0</notextile>')
				to_html = text_to_html(body)
				# if auto_linking is done in java side then we will not do
				if(!params[:auto_link_done].nil? && params[:auto_link_done].to_s.downcase == "true")
					body_html = to_html
				else
					# Process auto_link if the content is less than 300 KB, otherwise leave as text.
					if body.size < MAXIMUM_CONTENT_LIMIT
						body_html = auto_link(to_html) { |text| truncate(text, :length => 100) }
					else
						body_html = sanitize(to_html)
					end
				end

				html = white_list(body_html)
				html.gsub!("&amp;amp;", "&amp;")
				html
			end
			def text_to_html(body)
				result_string = ""
				body.each_char.with_index do |char, i|
					case (char)
					when "&"
						result_string << "&amp;"
					when "<"
						result_string << "&lt;"
					when ">"
						result_string << "&gt;"
					when "\t"
						result_string << "&nbsp;&nbsp;&nbsp;&nbsp;"
					when "\n"
						result_string << "<br>"
					when "\""
						result_string << "&quot;"
					when "\'"
						result_string << "&#39;"
					else
						result_string << char
					end
				end
				"<p>" + result_string + "</p>"
			end

			def create_new_user(account, from_email, email_config, force_create = false)
				if force_create || can_create_ticket?(from_email[:email])
					user = account.contacts.new
					language = (account.features?(:dynamic_content)) ? nil : account.language
					portal = (email_config && email_config.product) ? email_config.product.portal : account.main_portal
					begin
						signup_status = user.signup!({:user => {:email => from_email[:email], :name => from_email[:name],
						:helpdesk_agent => false, :language => language, :created_from_email => true }, :email_config => email_config},portal)
						raise UserCreationError, "Failed to create new Account!" unless signup_status
					rescue UserCreationError => e
						NewRelic::Agent.notice_error(e)
						Account.reset_current_account
						email_processing_log "Email Processing Failed: Couldn't create new user!"
						raise e
                    end
				else
					email_processing_log "Can't create new user for #{from_email.inspect}"
				end
				user
			end

			def set_current_user(user)
				user.make_current if user.present?
			end

			def fetch_ticket(account, from_email, user, email_config)
				if(account.fetch_ticket_from_ref_first_enabled?)
					ticket = fetch_ticket_from_references(account, from_email, user, email_config)
					return ticket unless ticket.nil?

					ticket = fetch_ticket_from_subject(account, from_email, user, email_config)
					return ticket unless ticket.nil?
				else
					ticket = fetch_ticket_from_subject(account, from_email, user, email_config)
					return ticket unless ticket.nil?

					ticket = fetch_ticket_from_references(account, from_email, user, email_config)
					return ticket unless ticket.nil?
				end

				ticket = fetch_ticket_from_email_body(account, from_email, user)
				return ticket unless ticket.nil?

				ticket = fetch_ticket_from_id_span(account, from_email, user)
				return ticket
			end

			def fetch_ticket_from_subject(account, from_email, user, email_config)
				display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.ticket_id_delimiter)
				ticket = account.tickets.find_by_display_id(display_id) if display_id
				if can_be_added_to_ticket?(ticket, user, from_email)
					Rails.logger.info 'Found existing ticket by display id present in subject'
					return ticket 
				end
			end

			def fetch_ticket_from_references(account, from_email, user, email_config)
				ticket = ticket_from_headers(from_email, account, email_config, user)
				if can_be_added_to_ticket?(ticket, user, from_email)
					Rails.logger.info 'Found existing ticket by references(reference, in-reply-to) present in header'
					return ticket 
				end
			end

			def fetch_ticket_from_email_body(account, from_email, user)
				ticket = ticket_from_email_body(account)
				if can_be_added_to_ticket?(ticket, user, from_email)
					Rails.logger.info 'Found existing ticket by fd_tkt_identifier present in HTML content'
					return ticket 
				end
			end

			def fetch_ticket_from_id_span(account, from_email, user)
				ticket = ticket_from_id_span(account)
				if can_be_added_to_ticket?(ticket, user, from_email)
					Rails.logger.info 'Found existing ticket by fdtktid present in HTML content'
					return ticket 
				end
			end

			def fetch_archived_ticket(account, from_email, user, email_config)
				display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.ticket_id_delimiter)
				archive_ticket = account.archive_tickets.find_by_display_id(display_id) if display_id
				return archive_ticket if can_be_added_to_ticket?(archive_ticket, user, from_email)
				archive_ticket = archive_ticket_from_headers(from_email, account, email_config, user)
				return archive_ticket if can_be_added_to_ticket?(archive_ticket, user, from_email)
				return self.actual_archive_ticket if can_be_added_to_ticket?(self.actual_archive_ticket, user, from_email)
			end

			def ticket_from_id_span(account)
				parsed_html = run_with_timeout(NokogiriTimeoutError) { Nokogiri::HTML(params[:html]) }
				display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
				unless display_span.blank?
					display_id, fetched_account_id = display_span.last.inner_html.split(":")
					display_span.last.remove
					params[:html] = parsed_html.inner_html
					unless display_id.blank?
						return if email_from_another_portal?(account, fetched_account_id)
						ticket = account.tickets.find_by_display_id(display_id.to_i)
						self.actual_archive_ticket = account.archive_tickets.find_by_display_id(display_id.to_i) if account.features_included?(:archive_tickets) && !ticket
						return ticket
					end
				end
			end

			def fetch_archive_or_normal_ticket_by_display_id display_id, account, is_archive = false
				if is_archive
					return account.archive_tickets.find_by_display_id(display_id)
				else
					account.tickets.find_by_display_id(display_id)
				end
			end

			def is_numeric?(str)
				true if Float(str) rescue false
			end

			def ticket_from_email_body(account)
				display_span = run_with_timeout(NokogiriTimeoutError) { 
					Nokogiri::HTML(params[:html]).css("span[title='fd_tkt_identifier']") 
				}
				unless display_span.blank?
					display_id, fetched_account_id = display_span.last.inner_html.split(":")
					unless display_id.blank?
						return if email_from_another_portal?(account, fetched_account_id)
						ticket = account.tickets.find_by_display_id(display_id.to_i)
						self.actual_archive_ticket = account.archive_tickets.find_by_display_id(display_id.to_i) if account.features_included?(:archive_tickets) && !ticket
						return ticket 
					end
				end
			end

			def add_to_or_create_ticket(account, from_email, to_email, user, email_config)
				ticket = nil
				archive_ticket = nil
				ticket, archive_ticket = process_email_ticket_info(account, from_email, user, email_config) unless account.skip_ticket_threading_enabled?
				if (ticket.present? || archive_ticket.present?) && user.blank?
					if archive_ticket
						parent_ticket = archive_ticket.parent_ticket
						if parent_ticket.is_a?(Helpdesk::Ticket) && can_be_added_to_ticket?(parent_ticket, user, from_email)
							valid_parent_ticket = true
						end
						linked_ticket = archive_ticket.ticket
						if linked_ticket && can_be_added_to_ticket?(linked_ticket.parent, user, from_email)
							valid_linked_ticket = true
							linked_ticket = linked_ticket.parent
						end
					end
					if ticket || valid_parent_ticket || valid_linked_ticket
						user = create_new_user(account, from_email, email_config, true)
						set_current_user(user)
					end
				end
				if user.blank?
					email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
					return processed_email_data(PROCESSED_EMAIL_STATUS[:blank_user], account.id)
				end
				params[:cc] = permissible_ccs(user, params[:cc], account)
				if ticket
					if(from_email[:email].to_s.downcase == ticket.reply_email.to_s.downcase) #Premature handling for email looping..
						email_processing_log "Email Processing Failed: Email cannot be threaded. From-email and Ticket's reply-email email are same!", to_email[:email]
						return processed_email_data(PROCESSED_EMAIL_STATUS[:self_email], account.id)
					end
					primary_ticket = check_primary(ticket,account)
					if primary_ticket
						return create_ticket(account, from_email, to_email, user, email_config) if primary_ticket.is_a?(Helpdesk::ArchiveTicket)
						ticket = primary_ticket
					end
					return add_email_to_ticket(ticket, from_email, to_email, user)
				else
					if archive_ticket
						self.archived_ticket = archive_ticket
						# If merge ticket change the archive_ticket
						if parent_ticket && parent_ticket.is_a?(Helpdesk::ArchiveTicket)
							self.archived_ticket = parent_ticket
						elsif valid_parent_ticket
							return add_email_to_ticket(parent_ticket, from_email, to_email, user)
						end
						# If not merge check if archive child present
						if valid_linked_ticket
							return add_email_to_ticket(linked_ticket, from_email, to_email, user)
						end
					end
					return create_ticket(account, from_email, to_email, user, email_config)
				end
			end

			def permissible_ccs(user, cc_emails, account)
				cc_emails, params[:dropped_cc_emails] = fetch_permissible_cc(user, cc_emails, account)
				cc_emails
			end  

			def check_primary(ticket,account)
				parent_ticket_id = ticket.schema_less_ticket.parent_ticket
				if !parent_ticket_id
					return nil
				elsif account.features_included?(:archive_tickets) && !ticket.parent
					archive_ticket = Helpdesk::ArchiveTicket.find_by_ticket_id(parent_ticket_id)
					archive_child_ticket = archive_ticket.ticket if archive_ticket
					return archive_child_ticket if archive_child_ticket

					self.archived_ticket = archive_ticket
					return archived_ticket
				else
					return ticket.parent
				end
			end

			def create_ticket(account, from_email, to_email, user, email_config)
				e_email = {}
				if (user.agent? && !user.deleted?)
					e_email = (account.features_included?(:disable_agent_forward) ? {} : orig_email_from_text) unless composed_email?
					if e_email[:cc_emails].present?
						params[:cc] = (params[:cc].present?) ? (params[:cc] << ", " << e_email[:cc_emails].join(", ")) : e_email[:cc_emails]
					end
					user = get_user(account, e_email , email_config, true) unless e_email.blank?
				end
				to_emails = parse_to_emails
				global_cc = parse_all_cc_emails(account.kbase_email, account.support_emails)
				if Account.current.allow_huge_ccs_enabled?
					global_cc = global_cc[0..48] if global_cc.present?
				elsif max_email_limit_reached? 'Ticket', to_emails, global_cc 
					email_processing_log "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for the ticket"
					return processed_email_data(PROCESSED_EMAIL_STATUS[:max_email_limit], account.id)
				end
				ticket_params = build_ticket_params account, user, to_email, global_cc, email_config
				ticket = Helpdesk::Ticket.new(ticket_params)
				ticket.sender_email = e_email[:email] || from_email[:email]
				ticket = check_for_chat_scources(ticket,from_email)
				ticket = check_and_mark_as_spam(ticket) #deleted user
				ticket.update_email_received_at(params[:x_received_at] || parse_internal_date(params[:internal_date]))
				check_for_auto_responders(ticket)
				check_support_emails_from(account, ticket, user, from_email)
				# Email commands edit the ticket properties here
				begin
					if (ticket.agent_performed?(user) && !user.deleted?)
						process_email_commands(ticket, user, email_config, params) if user.privilege?(:edit_ticket_properties)
						email_cmds_regex = get_email_cmd_regex(account)
						ticket.ticket_body.description = ticket.description.gsub(email_cmds_regex, "") if(!ticket.description.blank? && email_cmds_regex)
						ticket.ticket_body.description_html = ticket.description_html.gsub(email_cmds_regex, "") if(!ticket.description_html.blank? && email_cmds_regex)
					end
				rescue Exception => e
					NewRelic::Agent.notice_error(e)
				end
				message_key = zendesk_email || message_id
				ticket = update_spam_data(ticket)
				assign_language(user, account, ticket)
				# Creating attachments without attachable info
				# Hitting S3 outside create-ticket transaction
				self.class.trace_execution_scoped(['Custom/IncomingEmailHandler/ticket_attachments']) do
					# attachable info will be updated on ticket save
					ticket.attachments, ticket.inline_attachments = create_attachments(ticket, account)
				end

				unless params[:dropped_cc_emails].blank?
					ticket.cc_email[:dropped_cc_emails] = params[:dropped_cc_emails]
				end
				message_id_list = []
				begin
					self.class.trace_execution_scoped(['Custom/IncomingEmailHandler/tickets']) do
						message_id_list.push(message_key).push(all_message_ids).flatten!.uniq!
						(ticket.header_info ||= {}).merge!(:message_ids => message_id_list) unless message_id_list.blank?
						if large_email && duplicate_email?(from_email[:email], 
															to_email[:email],
															params[:subject],
															message_id)
							return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], account.id)
						end
						if account.features_included?(:archive_tickets) && archived_ticket
							ticket.build_archive_child(:archive_ticket_id => archived_ticket.id)
						end
						if params[:migration_tags]
							tags_hash = JSON.parse(params[:migration_tags])
							add_tags(tags_hash, account, ticket)
						end
						ticket.save_ticket!
						email_processing_log "Email Processing Successful: Email Successfully created as Ticket!!", to_email[:email]
						cleanup_attachments ticket
						# mark email as processed for all the emails
						mark_email(process_email_key, from_email[:email], 
									to_email[:email],
									params[:subject],
									message_id)
					end
                    rescue Aws::S3::Errors::ServiceError => e # PRE-RAILS4 Changed S3 base error class as InvalidURI is not available in V2
					# FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
					email_processing_log "Email Processing Failed: Couldn't store attachment in S3!", to_email[:email]
					raise e
				rescue ActiveRecord::RecordInvalid => e
					# FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
					NewRelic::Agent.notice_error(e)
				end
				
				if(!(ticket.spam == true && ticket.skip_notification == true))
					message_id_list.each do |msg_key|
						store_ticket_threading_info(account, msg_key, ticket)
					end
				end
				# ticket
				return processed_email_data(PROCESSED_EMAIL_STATUS[:success], account.id, ticket)
			end


			def orig_email_from_text #To process mails fwd'ed from agents
				@orig_email_user ||= begin
					content = text_part
					identify_original_requestor(content)
				end
			end

			def get_user(account, from_email, email_config, force_create = false)
				user = existing_user(account, from_email)
				unless user.present?
					if force_create || can_create_ticket?(from_email[:email])
						user = create_new_user(account, from_email, email_config, true)
					end
				end
				set_current_user(user)
			end

			def max_email_limit_reached? model_name, to_emails, cc_emails
				if model_name == "Note"
					return ((cc_emails.present? && (cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT)) || (to_emails.present? && (to_emails.count >= TicketConstants::MAX_EMAIL_COUNT))) 
				elsif model_name == "Ticket"
					return (cc_emails.present? && (cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT))
				end
			end

			def build_ticket_params account, user, to_email, global_cc, email_config
				ticket_params = {
					:account_id => account.id,
					:subject => params[:subject],
					:ticket_body_attributes => {
						description:      params[:text] || '',
						description_html: cleansed_html || ''
					},
					:requester => user,
					:to_email => to_email[:email],
					:to_emails => parse_to_emails,
					:cc_email => {:cc_emails => global_cc.dup, :fwd_emails => [],
						:bcc_emails => [], :reply_cc => global_cc.dup, :tkt_cc => parse_cc_email },
					:email_config => email_config,
					:status => Helpdesk::Ticketfields::TicketStatus::OPEN,
					:source => Account.current.helpdesk_sources.ticket_source_keys_by_token[:email]
				}
				ticket_params.merge!({
					:created_at => params[:migration_internal_date].to_time,
					:updated_at => params[:migration_internal_date].to_time,
					:status => params[:migration_status]
				}) if (params[:migration_internal_date] && params[:migration_status])
				ticket_params
			end

			def parse_cc_email
				cc_array = get_email_array params[:cc]
				cc_array.concat(additional_emails || [])
				cc_array.compact.map{|i| i.downcase}.uniq
				if Account.current.allow_huge_ccs_enabled?
					cc_array = cc_array[0..48]
				end
				cc_array
			end

			def cleansed_html
				if (params[:cleanse_done].nil? or params[:cleanse_done].to_s.downcase == "false")
					@cleaned_html_body ||= begin
						cleansed_html = run_with_timeout(HtmlSanitizerTimeoutError) { 
						begin
							result = nil
							if (!params[:sanitize_done].nil? && params[:sanitize_done].to_s.downcase == "true")
								result = params[:html]
							else
								params[:html] = Nokogiri::HTML(params[:html]).to_html if params[:html].present?
								result = Helpdesk::HTMLSanitizer.clean params[:html]
								result = Nokogiri::HTML.parse(result).css('body').inner_html
							end
						rescue SystemStackError => e
							result = handle_system_stack_error e
						end
						result
						}
					end
				else
					params[:html]
				end
			end

			def parse_to_emails
				fetch_valid_emails params[:to]
			end

			def check_for_chat_scources(ticket,from_email)
				ticket.source = Account.current.helpdesk_sources.ticket_source_keys_by_token[:chat] if Helpdesk::Ticket::CHAT_SOURCES.has_value?(from_email[:domain])
				if from_email[:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
					emailreg = Regexp.new(/\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
					chat_email =  params[:subject].scan(emailreg).uniq[0]
					ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
				end
				ticket
			end

			def check_and_mark_as_spam(ticket)
				if ticket.requester.deleted?
					ticket.spam = true
					Rails.logger.info "Ticket #{ticket.id} marked as spam due to deleted User"
				end
				ticket  
			end

			def check_for_auto_responders(model)
				if (params[:migration_skip_notification] || auto_generated?(params[:headers]))
					model.skip_notification = true
					Rails.logger.info "Skip notification is set due to auto_generated or migration"
				end
			end

			def auto_generated?(headers)
				!headers.blank? && (
				(headers =~ /Auto-Submitted: auto-(.)+/i) || 
				(headers =~ /Precedence: auto_reply/) || 
				(headers =~ /Precedence: (bulk|junk)/i)
				)
			end

			def check_support_emails_from(account, model, user, from_email)
				if user && account.support_emails.any? {|email| email.casecmp(from_email[:email]) == 0}
					model.skip_notification = true
					Rails.logger.info "Skip notification set due to email identified from support email"
				end
			end

			def update_spam_data(ticket)
				# check if spam check done @ email service. If not do it here.
				if(!params[:spam_done].nil? && params[:spam_done].to_s.downcase == "true")
					spam_data = JSON.parse(params[:spam_info])
				else
					spam_data = check_for_spam(params) 
					# add is_spam attribute if spam check done locally
					spam_data.merge!({'is_spam' => spam_data['spam']}).with_indifferent_access
				end
				if(spam_data.present?)
				# check the intersection of 2 arrays(affected rules and spam rules) and ensure the spam rule present
					if(!spam_data['rules'].nil? && (spam_data['rules'] & custom_bot_attack_rules).size != 0)
						ticket.skip_notification = true;
						ticket.spam = true;
						Rails.logger.info "Skip notification set and ticket marked as spam due to CUSTOM_BOT_ATTACK"
					end

					if (antispam_enabled?(ticket.account))
						begin
							ticket.spam_score = spam_data['score']
							ticket.spam = true if spam_data['is_spam'] == true
							Rails.logger.info "Spam rules triggered for ticket with message_id #{params[:message_id]}: #{spam_data['rules'].inspect}"
						rescue => e
							Rails.logger.info e.message
						end
					end
				end
				begin
					if Account.current.email_spoof_check_feature?
						spam_data ||= JSON.parse(params[:spam_info])
						ticket.schema_less_ticket.additional_info.merge!(generate_spoof_data_hash(spam_data))
					end
				rescue Exception => e
					Rails.logger.error("Exception wile parsing spam info hash for email spoof data :: #{e.inspect} :: #{e.backtrace}")
					NewRelic::Agent.notice_error(e, description: 'error occured while trying to parse spam_info')
				end
				ticket
			end

			def create_attachments(item, account)
				attachments = []
				inline_attachments = []
				content_id_hash = {}
				inline_count = 0
				content_ids = params["content-ids"].nil? ? {} : get_content_ids

				Integer(params[:attachments]).times do |i|
					begin
						if params["attachment#{i+1}"].nil?
							Rails.logger.info("Create attachment skipped for attachment#{i+1} Reason : Attachment object is nil")
							next
						end
						content_id = content_ids["attachment#{i+1}"] && 
										verify_inline_attachments(item, content_ids["attachment#{i+1}"])
						att = Helpdesk::Attachment.create_for_3rd_party(account, item,
								params["attachment#{i+1}"], i, content_id, true)
						if att && (att.is_a? Helpdesk::Attachment)
							if content_id && !att["content_file_name"].include?(".svg")
								content_id_hash[att.content_file_name+"#{inline_count}"] = content_ids["attachment#{i+1}"]
								inline_count+=1
								inline_attachments.push att
							else
								attachments.push att
							end
							att.skip_virus_detection = true
						end
					rescue HelpdeskExceptions::AttachmentLimitException => ex
						Rails.logger.error("ERROR ::: #{ex.message}")
						message = attachment_exceeded_message(ATTACHMENT_LIMIT.megabytes)
						add_notification_text item, message
						break
					rescue Exception => e
						Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
						raise e
					end
				end
				if @total_virus_attachment
					message = virus_attachment_message(@total_virus_attachment)
					add_notification_text item, message
				end
				item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
				return attachments, inline_attachments
			end

			def get_content_ids
				content_ids = {}
				split_content_ids = params["content-ids"].tr("{}\\\"","").split(",")
				split_content_ids.each do |content_id|
					split_content_id = content_id.split(":")
					content_ids[split_content_id[1]] = split_content_id[0]
				end
				content_ids
			end

			def add_notification_text item, message
				notification_text = "\n" << message
				notification_text_html = Helpdesk::HTMLSanitizer.clean(content_tag(:div, message, :class => "attach-error"))
				if item.is_a?(Helpdesk::Ticket)
					item.description << notification_text
					item.description_html << notification_text_html
				elsif item.is_a?(Helpdesk::Note)
					item.body << notification_text
					item.body_html << notification_text_html
				end
			end

			def add_tags tags_hash, account, ticket
				if tags_hash.present?
					tags_hash.each do |tag_name|
						custom_tag = account.tags.find_by_name(tag_name)
						custom_tag = account.tags.create(:name => tag_name) if custom_tag.nil?
						ticket.tags << custom_tag unless (ticket.tags.include? custom_tag)
					end
				end
			end

			def store_ticket_threading_info(account, message_id, ticket)
				related_ticket_info = get_ticket_info_from_redis(account, message_id)
				if related_ticket_info
					ticket_id_list = $1 if related_ticket_info =~ /(.+?):/
				end
				related_tickets_display_info = ticket_id_list.present? ? ((ticket_id_list.to_s) +","+ (ticket.display_id.to_s)) : ticket.display_id.to_s

				set_ticket_id_with_message_id account, message_id, related_tickets_display_info
			end

			def add_email_to_ticket(ticket, from_email, to_email, user)
				msg_hash = {}
				# for plain text
				body = params[:body_content_text]
				# work with the code here
				full_text = params[:text]
				if need_local_quoted_parsing?
					msg_hash = show_quoted_text(params[:text], ticket.reply_email)
					unless msg_hash.blank?
						body = msg_hash[:body]
						full_text = msg_hash[:full_text]
					end
				end

				# for html text
				body_html = (quoted_parsing_enabled?) ? params[:body_content_html] : params[:html]
				full_text_html =  params[:html]

				if need_local_quoted_parsing?
					msg_hash = show_quoted_text(params[:html], ticket.reply_email,false)
					unless msg_hash.blank?
						body_html = msg_hash[:body]
						full_text_html = msg_hash[:full_text]
					end
				end

				from_fwd_recipients = from_fwd_emails?(ticket, from_email)
				parsed_cc_emails = parse_cc_email
				parsed_cc_emails.delete(ticket.account.kbase_email)
				cc_emails = parsed_cc_emails
				to_emails = parse_to_emails

				if Account.current.allow_huge_ccs_enabled?
					cc_emails = cc_emails[0..48] if cc_emails.present?
					to_emails = to_emails[0..48] if to_emails.present?
				elsif max_email_limit_reached? 'Note', to_emails, cc_emails
					email_processing_log "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for the note"
					return processed_email_data(PROCESSED_EMAIL_STATUS[:max_email_limit], ticket.account.id)
				end
				note_params = build_note_params ticket, from_email, user, from_fwd_recipients, body, body_html, full_text, full_text_html, cc_emails
				note = ticket.notes.build note_params
				note.quoted_parsing_done= "1" if  quoted_parsing_enabled? && !need_local_quoted_parsing?
				note.subject = (params[:cleanse_done].nil? or params[:cleanse_done].to_s.downcase == "false") ? Helpdesk::HTMLSanitizer.clean(params[:subject]) : params[:subject]
				note.source = Account.current.helpdesk_sources.note_source_keys_by_token["note"] if (from_fwd_recipients or ticket.agent_performed?(user) or rsvp_to_fwd?(ticket, from_email, user))

				note.schema_less_note.category = ::Helpdesk::Note::CATEGORIES[:third_party_response] if rsvp_to_fwd?(ticket, from_email, user)
				note.update_email_received_at(params[:x_received_at] || parse_internal_date(params[:internal_date]))

				check_for_auto_responders(note)
				check_support_emails_from(ticket.account, note, user, from_email)

				# Process email commands and remove the emil-cmd-regex in body, body_html, full_text, full_text_html
				begin
					ticket.cc_email = ticket_cc_emails_hash(ticket, note)
					if (ticket.agent_performed?(user) && !user.deleted?)
						process_email_commands(ticket, user, ticket.email_config, params, note) if user.privilege?(:edit_ticket_properties)
						email_cmds_regex = get_email_cmd_regex(ticket.account)
						note.note_body.body = body.gsub(email_cmds_regex, "") if(!body.blank? && email_cmds_regex)
						note.note_body.body_html = body_html.gsub(email_cmds_regex, "") if(!body_html.blank? && email_cmds_regex)
						note.note_body.full_text = full_text.gsub(email_cmds_regex, "") if(!full_text.blank? && email_cmds_regex)
						note.note_body.full_text_html = full_text_html.gsub(email_cmds_regex, "") if(!full_text_html.blank? && email_cmds_regex)
					end
				rescue Exception => e
					NewRelic::Agent.notice_error(e)
				end

				# Creating attachments without attachable info
				# Hitting S3 outside create-note transaction
				self.class.trace_execution_scoped(['Custom/IncomingEmailHandler/note_attachments']) do
					# attachable info will be updated on note save
					note.attachments, note.inline_attachments = create_attachments(note, ticket.account)
				end

				unless params[:dropped_cc_emails].blank?
					note.cc_emails = {:cc_emails => note.cc_emails, :dropped_cc_emails => params[:dropped_cc_emails]}
				end

				self.class.trace_execution_scoped(['Custom/IncomingEmailHandler/notes']) do

					note.notable = ticket
					if duplicate_email?(from_email[:email], 
					                  parse_to_emails.first, 
					                  params[:subject], 
					                  message_id)
					return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], ticket.account_id)
				end
				if params[:migration_tags]
					tags_hash = JSON.parse(params[:migration_tags])
					add_tags(tags_hash, ticket.account, ticket)
				end
				note.save_note
				email_processing_log "Email Processing Successful: Email Successfully created as Note!!", to_email[:email]
				cleanup_attachments note
				mark_email(process_email_key, from_email[:email], 
				      to_email[:email], 
				      params[:subject], 
				      message_id)
				end

				return processed_email_data(PROCESSED_EMAIL_STATUS[:success], note.account_id, note)
			end


			def build_note_params ticket, from_email, user, from_fwd_recipients, body, body_html, full_text, full_text_html, cc_emails
				hide_response_from_customer = ticket.account.launched?(:hide_response_from_customer_feature)? (customer_removed_in_reply?(ticket, in_reply_to, parse_to_emails, cc_emails, from_email)): false
				note_params = {
					:private => (from_fwd_recipients or reply_to_private_note?(all_message_ids) or rsvp_to_fwd?(ticket, from_email, user) or hide_response_from_customer),
					:incoming => true,
					:note_body_attributes => {
						body:           body || '',
						body_html:      body_html || '',
						full_text:      full_text,
						full_text_html: full_text_html || ''
					},
					:source => Account.current.helpdesk_sources.note_source_keys_by_token["email"],
					:user => user, #by Shan temp
					:account_id => ticket.account_id,
					:from_email => from_email[:email],
					:to_emails => parse_to_emails,
					:cc_emails => cc_emails
				}
				note_params.merge!({
					:created_at => params[:migration_internal_date].to_time,
					:updated_at => params[:migration_internal_date].to_time
				}) if params[:migration_internal_date]
				note_params
			end


			def from_fwd_emails?(ticket,from_email)
				cc_email_hash_value = ticket.cc_email_hash
				unless cc_email_hash_value.nil?
					cc_email_hash_value[:fwd_emails].any? {|email| email.include?(from_email[:email].downcase) }
				else
					false
				end
			end

			def rsvp_to_fwd?(ticket, from_email, user)
				@rsvp_to_fwd ||= ((Account.current.features?(:threading_without_user_check) || (!ticket.cc_email.nil? && !ticket.cc_email[:cc_emails].nil? && ticket.cc_email[:cc_emails].include?(from_email[:email])) || user.agent?) && reply_to_forward(all_message_ids))
			end

			def ticket_cc_emails_hash(ticket, note)
				to_email   = parse_to_email[:email]
				to_emails  = get_email_array(params[:to])
				new_cc_emails = parse_cc_email
				updated_ticket_cc_emails(new_cc_emails, ticket, note, in_reply_to, 
				to_email, to_emails)
			end

			def create_article(account, from_email, to_email)

				article_params = {}

				email_config = account.email_configs.find_by_to_email(to_email[:email])
				user = get_user(account, from_email, email_config)

				article_params[:title] = params[:subject].gsub( encoded_display_id_regex(account), "" )

				article_params[:description] = cleansed_html || simple_format(params[:text])
				article_params[:user] = user.id
				article_params[:account] = account.id
				article_params[:content_ids] = params["content-ids"].nil? ? {} : get_content_ids

				article_params[:attachment_info] = JSON.parse(params["attachment-info"]) if params["attachment-info"]
				attachments = {}

				Integer(params[:attachments]).times do |i|
					attachments["attachment#{i+1}"] = params["attachment#{i+1}"]
				end

				article_params[:attachments] = attachments
				article = Helpdesk::KbaseArticles.create_article_from_email(article_params)
				if article.present?
					return processed_email_data(PROCESSED_EMAIL_STATUS[:success], account.id, article) 
				else
					return processed_email_data(PROCESSED_EMAIL_STATUS[:failed_article], account.id)
				end
			end

			def fetch_subject_from_header
				params[:headers] =~ /^subject\s*:(.+)$/i
				subject = $1.strip
				detected_encoding = CharlockHolmes::EncodingDetector.detect(subject)
				detected_encoding = {:encoding => "UTF-8"} if detected_encoding.nil?
				return subject, detected_encoding
			end


			def check_for_spam(params)
				begin
					Helpdesk::Email::SpamDetector.new.check_spam(params, params[:envelope])
				rescue Exception => e
					Rails.logger.info "Error during spam_check in incoming_email_handler. #{e.message} - #{e.backtrace}"
					NewRelic::Agent.notice_error(e)
				end
			end

			def show_quoted_text(text, address,plain=true)

				return text if text.blank?

				Timeout.timeout(LARGE_TEXT_TIMEOUT) do
        			from_all_regex = $redis_others.perform_redis_op('get', QUOTED_TEXT_PARSE_FROM_REGEX) || 'from'
					regex_arr = get_quoted_text_regex_array(address, from_all_regex)
					tl = text.length

					#calculates the matching regex closest to top of page
					index = regex_arr.inject(tl) do |min, regex|
						(text.index(regex) or tl) < min ? (text.index(regex) or tl) : min
					end

					original_msg = text[0, index]
					old_msg = text[index,text.size]

					return  {:body => original_msg, :full_text => text } if plain
					#Sanitizing the original msg
					unless original_msg.blank?
						sanitized_org_msg = Nokogiri::HTML(original_msg).at_css("body")
						unless sanitized_org_msg.blank?
							remove_identifier_span(sanitized_org_msg)
							original_msg = sanitized_org_msg.inner_html
						end
					end
					#Sanitizing the old msg
					unless old_msg.blank?
						sanitized_old_msg = Nokogiri::HTML(old_msg).at_css("body")
						unless sanitized_old_msg.blank?
							remove_identifier_span(sanitized_old_msg)
							remove_survey_div(sanitized_old_msg) unless plain
							old_msg = sanitized_old_msg.inner_html
						end
					end

					full_text = original_msg
					unless old_msg.blank?

						full_text = full_text +
						"<div class='freshdesk_quote'>" +
						"<blockquote class='freshdesk_quote'>" + old_msg + "</blockquote>" +
						"</div>"
					end
					return {:body => full_text,:full_text => full_text}  #temp fix made for showing quoted text in incoming conversations
				end
				rescue => e
					Rails.logger.info "Exception in show_quoted_text , message :#{e.message} - #{e.backtrace}"
				return {:body => text,:full_text => text}
			end

			def get_quoted_text_regex_array(address, from_all_regex)
				[
					Regexp.new("#{from_all_regex}:\s*" + Regexp.escape(address), Regexp::IGNORECASE),
					Regexp.new("<" + Regexp.escape(address) + ">", Regexp::IGNORECASE),
					Regexp.new(Regexp.escape(address) + "\s+wrote:", Regexp::IGNORECASE),
					Regexp.new("<div>\n<br>On.*?wrote:"), 
					Regexp.new("On((?!On).)*wrote:"),
					Regexp.new("-+original\s+message-+\s*", Regexp::IGNORECASE),
					Regexp.new("#{from_all_regex}:\s*", Regexp::IGNORECASE)
				]
			end

			def encoded_display_id_regex account
				Regexp.new("\\[#{account.ticket_id_delimiter}([0-9]*)\\]")
			end
			def get_email_parsing_redis_flag
				if $last_time_checked.blank? || $last_time_checked < 5.minutes.ago
					$email_parsing_redis_flag = get_others_redis_key(QUOTED_TEXT_PARSING_NOT_REQUIRED)
					$last_time_checked = Time.now
				end
				return $email_parsing_redis_flag
			end

			def need_local_quoted_parsing?
				(params[:quoted_parse_done].nil? or params[:quoted_parse_done].to_s.downcase == "false")
			end

			# quoted parsing done in email_service. This flag enables the body_html to be saved as simple recent reply.
			# if this returns false then full_html is saved in body_html also
			def quoted_parsing_enabled?
				((get_email_parsing_redis_flag == "1") or Account.current.launched?(:quoted_text_parsing_feature))
			end

		end



		add_method_tracer :check_for_spam, 'Custom/EmailServiceController/spam_check'

	end
end
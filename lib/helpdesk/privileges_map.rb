module Helpdesk
	module PrivilegesMap

		CHAT_PRIVILEGE_MAP = {
			:manage_canned_responses => [:livechat_manage_shortcodes],
			:manage_tickets => [:livechat_manage_visitor, :livechat_view_transcripts,:livechat_edit_transcripts, 
								:livechat_accept_chat, :livechat_initiat_agent_chat, :livechat_view_visitors,
								:livechat_intiate_visitor_chat, :livechat_export_transcripts],
			:delete_ticket => [:livechat_delete_transcripts],
			:view_reports => [:livechat_view_reports],
			:admin_tasks => [:livechat_admin_tasks, :livechat_shadow_chat]
		}

		REPORTS_PRIVILEGE_MAP = {
			:view_reports => [:export_reports]
		}

		FORUM_PRIVILEGES_MAP = {
			:view_forums => [:forum_basic_moderator],
			:manage_forums => [:forum_advanced_moderator, :forums_exports],
			:admin_tasks => [:forums_admin_moderator],
			:view_reports => [:forums_view_reports]
		}

		SOLUTION_PRIVILEGES_MAP = { 
			:view_solutions => [:create_solution_draft, :solution_view_versions],
			:manage_solutions => [:solution_exports, :solution_delete_versions, :solution_restore_versions],
			:view_reports => [:solution_view_reports]
		}

		CUSTOMER_PRIVILEGE_MAP = {
			:view_contacts => [:export_customers],
			:manage_contacts => [:import_customers]

		}

		SOCIAL_PRIVILEGES_MAP = {
			:manage_tickets => [:view_social,:social_convert_to_ticket],
			:reply_ticket => [:social_reply_and_compose_post,:manage_social_response]
		}

		HELPDESK_PRIVILEGE_MAP = {
			:manage_tickets => [:export_tickets],
			:edit_note => [:edit_private_note],
			:edit_ticket_properties => [:assign_agent,:assign_group]
		}


		ALL_PRIVILEGES = [HELPDESK_PRIVILEGE_MAP,SOCIAL_PRIVILEGES_MAP,CUSTOMER_PRIVILEGE_MAP,
			               SOLUTION_PRIVILEGES_MAP,FORUM_PRIVILEGES_MAP,REPORTS_PRIVILEGE_MAP,CHAT_PRIVILEGE_MAP]

		MIGRATION_MAP = ALL_PRIVILEGES.inject({}) do |hash, pr_map|
							hash.merge!(pr_map) {|key,oldval,newval| oldval | newval}
	   						hash
						end

	end

end




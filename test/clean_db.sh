#!/bin/bash
db_name=$1

# list of tables having meta data - should not be truncated
table_list=(
    account_additional_settings
    account_configurations
    accounts
    admin_user_accesses
    agent_types
    business_calendars
    ca_folders
    chat_settings
    chat_widgets
    company_field_choices
    company_fields
    company_forms
    contact_fields
    contact_forms
    day_pass_configs
    denormalized_flexifields
    domain_mappings
    email_configs
    email_notifications
    flexifield_defs
    flexifields
    forum_moderators
    global_blacklisted_ips
    group_types
    helpdesk_picklist_values
    helpdesk_ticket_fields
    helpdesk_ticket_statuses
    helpdesk_choices
    oauth_applications
    password_policies
    portal_templates
    portals
    roles
    schema_migrations
    scoreboard_levels
    scoreboard_ratings
    service_api_keys
    shard_mappings
    sla_details
    sla_policies
    subscription_addons
    subscription_currencies
    subscription_plan_addons
    subscription_plans
    subscriptions
    user_accesses
    widgets
)

mysql -u root -Nse "show tables" $db_name | while read table; do
    if [[ ! ("${table_list[*]}" =~ $table) ]]; then
        echo "truncate table > $table"
        mysql -u root -e "truncate table $table" $db_name
    fi
done
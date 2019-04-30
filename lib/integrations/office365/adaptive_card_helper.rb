module Integrations::Office365::AdaptiveCardHelper
  EMAIL_HTML_ADAPTIVE =
    "<html>
      <head>
        <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
        <script type=\"application/adaptivecard+json\">
          %{adaptive_card_content}
        </script>
        <script type=\"application/ld+json\">
          %{message_card_content}
        </script>
      </head>
      <body>
        %{hidden_ticket_identifier}
      </body>
    </html>".freeze

  private

    def generate_adaptive_card_payload
      payload = {
        "$schema": 'http://adaptivecards.io/schemas/adaptive-card.json',
        "type": 'AdaptiveCard',
        "version": '1.0',
        "padding": 'none',
        "body": adaptive_card_body
      }
      payload[:originator] = originator if originator.present?
      payload
    end

    def adaptive_card_body
      [title_part, description_part, actionable_part, link_to_ticket]
    end

    def padding(left = 'small', right = 'small', top = 'small', bottom = 'small')
      {
        "left": left,
        "right": right,
        "top": top,
        "bottom": bottom
      }
    end

    def title_part
      {
        "type": 'Container',
        "style": 'emphasis',
        "padding": padding,
        "items": [
          {
            "type": 'ColumnSet',
            "spacing": 'none',
            "columns": [
              {
                "type": 'Column',
                "width": 'stretch',
                "padding": padding('small', 'small', 'small', 'none'),
                "items": [
                  {
                    "type": 'TextBlock',
                    "text": account_name,
                    "isSubtle": 'True',
                    "weight": 'Bolder',
                    "height": 'stretch',
                    "size": 'Medium'
                  }
                ]
              },
              {
                "type": 'Column',
                "items": [
                  {
                    "type": 'Image',
                    "horizontalAlignment": 'Right',
                    "url": freshdesk_logo_url,
                    "size": 'Small'
                  }
                ],
                "width": 'auto'
              }
            ]
          }
        ]
      }
    end

    def freshdesk_logo_url
      "https://#{account.full_domain}/images/misc/admin-logo.png"
    end

    def description_part
      {
        "type": 'Container',
        "spacing": 'none',
        "padding": padding,
        "separator": 'True',
        "items": [
          {
            "type": 'ColumnSet',
            "spacing": 'none',
            "columns": [
              {
                "width": 'stretch',
                "items": [
                  {
                    "size": 'medium',
                    "text": title_for_message_card,
                    "type": 'TextBlock',
                    "wrap": 'True',
                    "height": 'stretch'
                  }
                ],
                "type": 'Column'
              }
            ]
          },
          {
            "wrap": true,
            "type": 'TextBlock',
            "size": 'medium',
            "text": trim_message,
            "height": 'stretch'
          }
        ]
      }
    end

    def actionable_part
      {
        "type": 'Container',
        "padding": padding('small', 'small', 'none', 'small'),
        "items": [
          {
            "type": 'ActionSet',
            "actions": [note_action, priority_action, agent_action]
          }
        ]
      }
    end

    def link_to_ticket
      {
        "type": 'Container',
        "separator": true,
        "padding": padding('small', 'small', 'none', 'small'),
        "items": [
          {
            "type": 'ColumnSet',
            "spacing": 'none',
            "columns": [
              {
                "width": 'stretch',
                "padding": padding('small', 'small', 'small', 'none'),
                "items": [
                  {
                    "type": 'TextBlock',
                    "text": "[View in Freshdesk](#{ticket_url})",
                    "horizontalAlignment": 'right',
                    "size": 'small'
                  }
                ],
                "type": 'Column'
              }
            ]
          }
        ]
      }
    end

    def note_action
      placeholder = build_text_placeholder('note', false, true, 'Enter your note.')
      action = build_body_action("#{target_url}/note", { note: '{{note.value}}' }, 'Add Private Note')

      generate_adaptive_card(true, [placeholder, action], 'Add Note')
    end

    def priority_action
      placeholder = build_choices_placeholder('priority', false, priority_hash)
      action = build_body_action("#{target_url}/priority", { priority: '{{priority.value}}' }, 'Update')

      generate_adaptive_card(true, [placeholder, action], 'Priority')
    end

    def agent_action
      placeholder = build_choices_placeholder('agent', false, agents_hash)
      action = build_body_action("#{target_url}/agent", { agent: '{{agent.value}}' }, 'Update')

      generate_adaptive_card(true, [placeholder, action], 'Agent')
    end

    def build_text_placeholder(id, is_required, is_multiline, placeholder)
      {
        "id": id,
        "isRequired": is_required,
        "isMultiline": is_multiline,
        "placeholder": placeholder,
        "type": 'Input.Text'
      }
    end

    def build_choices_placeholder(id, is_required, choices)
      {
        "id": id,
        "isRequired": is_required,
        "choices": format_choices(choices),
        "type": 'Input.ChoiceSet'
      }
    end

    def format_choices(choices)
      choices.map { |k, v| { title: k, value: v.to_s } }
    end

    def build_body_action(actionable_url, value_reference, title)
      body = { ticket_id: ticket.id }.merge(value_reference).to_json
      {
        "actions": [
          {
            "hideCardOnInvoke": false,
            "method": 'POST',
            "url": actionable_url,
            "headers": [
              {
                "name": 'Content-Type',
                "value": 'application/json'
              }
            ],
            "body": body,
            "title": title,
            "type": 'Action.Http'
          }
        ],
        "spacing": 'Small',
        "type": 'ActionSet'
      }
    end

    def generate_adaptive_card(is_primary, body, title)
      action = {
        "card": {
          "type": 'AdaptiveCard',
          "$schema": 'http://adaptivecards.io/schemas/adaptive-card.json'
        }.merge(body: body),
        "title": title,
        "type": 'Action.ShowCard'
      }

      action[:isPrimary] = 'true' if is_primary
      action
    end
end

account = Account.current
user = User.current
folder_id = account.canned_response_folders.where(folder_type: Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:personal]).first.id

account.canned_responses.create(
  title: I18n.t('fixtures.canned_response.title'),
  helpdesk_accessible_attributes: {
    user_ids: user.id,
    access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  },
  folder_id: folder_id,
  content_html: %q(
    <div dir="ltr">
        <div>Hello {{ticket.requester.name}} <br><br>
            Name: {{ticket.requester.firstname}} {{ticket.requester.lastname}} <br>
            Email:{{ticket.from_email}}<br>
            Address: {{ticket.requester.address}}<br>
            OrderID: &lt;Fill in the Order ID here&gt; <br>
            <br><br>
            Regards,
            {{ticket.agent.name}}<br>
            {{helpdesk_name}} Support
            <br><br>
            Please check this link for ticket status: {{ticket.url}} 
        </div>
    </div>
  )
)
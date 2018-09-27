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
      Thank you for reaching out to us. Our team will look into your request and get back to you shortly. 
      <br>
      <br>
      You can check the status of your request and add comments here:
      <br>
      {{ticket.url}}
      <br>
      <br>
      Regards,<br>
      {{ticket.agent.name}}
    </div>
  )
)
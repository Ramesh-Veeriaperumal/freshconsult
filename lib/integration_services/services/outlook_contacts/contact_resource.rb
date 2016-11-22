module IntegrationServices::Services
  module OutlookContacts
    class ContactResource < OutlookContactsResource

      def fetch_contacts(url)
        response = { 'value' => [] }
        while url.present?
          res = http_get(url, nil, { "Prefer" => "odata.track-changes, odata.maxpagesize=100" })
          res = process_response(res, 200, &extract_body)
          response['value'].concat(res['value'])
          if res["@odata.nextLink"].present?
            url = res["@odata.nextLink"]
          elsif url.downcase.exclude?("deltatoken")
            url = res['@odata.deltaLink']
          else
            response['@odata.deltaLink'] = res['@odata.deltaLink']
            url = nil
          end
        end
        response
      end

      def create_contact(contact, folder_id)
        url = folder_contacts_url(folder_id)
        response = http_post(url, contact.to_json)
        response = process_response(response, 201, &extract_body)
        response["Id"]
      end

      def update_contact(contact, contact_id)
        url = contact_id_url(contact_id)
        response = http_patch(url, contact.to_json)
        process_response(response, 200, &extract_body)
      end

      def delete_contact(contact_id)
        url = contact_id_url(contact_id)
        response = http_delete(url)
        process_response(response, 204, &extract_body)
      end

      def default_contacts_url
        outlook_rest_url + "/contacts"
      end

      def folder_contacts_url(folder_id)
        outlook_rest_url + "/contactfolders/#{folder_id}/contacts"
      end

      def contact_id_url(contact_id)
        outlook_rest_url + "/contacts/#{contact_id}"
      end

      private

        def extract_body
          lambda { |resp| resp }
        end

        def extract_value
          lambda { |resp| resp['value'] }
        end

    end
  end
end

module IntegrationServices::Services
  module OutlookContacts
    class FolderResource < OutlookContactsResource

      def fetch_folders
        folders = []
        url = all_folders_url
        while url.present?
          response = http_get(url, nil, {})
          res = process_response(response, 200, &extract_value)
          folders.concat(res['value'])
          if res["@odata.nextLink"].present?
            url = res["@odata.nextLink"]
          else
            url = nil
          end
        end
        folders
      end

      def create_folder(folder_name)
        url = create_folder_url
        folder = { "DisplayName" => folder_name }
        response = http_post(url, folder.to_json)
        response = process_response(response, 201, &extract_body)
        response['Id']
      end

      def all_folders_url
        outlook_rest_url + "/contactfolders?$orderby=DisplayName&$top=50"
      end

      def create_folder_url
        outlook_rest_url + "/contactfolders"
      end

      private

        def extract_value
          lambda { |resp| resp }
        end

        def extract_body
          lambda { |resp| resp }
        end

    end
  end
end

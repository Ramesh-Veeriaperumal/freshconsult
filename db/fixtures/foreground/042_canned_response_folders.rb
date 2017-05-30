account = Account.current

Admin::CannedResponses::Folder.seed_many(:account_id, :name,[
                                           { :name         =>  'General',
                                             :is_default   =>  true,
                                             :account_id   =>  account.id,
                                             :folder_type  =>  Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:default]
                                             },
                                           { :name         =>  "Personal_#{account.id}",
                                             :is_default   =>  true,
                                             :account_id   =>  account.id,
                                             :folder_type  =>  Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:personal]
                                             }]
                                         )

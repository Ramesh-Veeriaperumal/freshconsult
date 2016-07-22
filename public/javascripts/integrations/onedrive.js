function openFromSkyDrive(inp) {
    WL.fileDialog({
        mode: 'open',
        select: 'single'
    }).then(
        function(response) {
            var file = response.data.files[0],
                link = response.data.files[0].link,
                splitArray = link.split('&');
            var resID = splitArray[2].split('=');
            new Ajax.Request("/integrations/onedrive/onedrive_view", {
                asynchronous: true,
                method: "get",
                dataType: "json",
                contentType: "application/json; charset=utf-8",
                parameters: { "res_id": resID[1] },
                onSuccess: function(reqData) {
                    var response = reqData.responseJSON;
                    var file_list = window.localStorage.getItem('current-file-list');
                    if (response.status == "success") {
                        function singleFile() {
                            var inputElement = jQuery(inp).data('holder');
                            jQuery('#' + inputElement).val(JSON.stringify({
                                link: response.url,
                                name: file.name,
                                provider: 'onedrive'
                            })).data('filename', file.name).data('provider', 'onedrive');
                            Helpdesk.Multifile.addFileToList(jQuery('#' + inputElement));
                            newInput = Helpdesk.Multifile.duplicateInput(jQuery('#' + inputElement));
                            jQuery(inp).data('holder', newInput.attr('id'));
                        }
                            // single file 
                            if (jQuery('.single_file').length !== 0 ) {
                                singleFile();
                            } else {
                                var attachments = JSON.stringify({ link: response.url, name: file.name, provider: 'onedrive' });
                                jQuery("#attach-limt-" + file_list).hide();
                                var cloud_file_object = [{ fileName: file.name, provider: 'One drive', attachments: attachments }];
                                jQuery("#attachment-template").tmpl({
                                    render_type: "new",
                                    type: "cloud",
                                    files: cloud_file_object
                                }).appendTo(".multiple-filelist-" + file_list);
                            }


                    } else {
                        jQuery('#noticeajax').html("Some Problem has occured in opening your onedrive files").show();
                        closeableFlash('#noticeajax');
                        window.scrollTo(0, 0);
                    }
                },
                onFailure: function(reqData) {}
            });
        });
}

Helpdesk = Helpdesk || {};
(function($) {
    Helpdesk.MultipleFileUpload = {
        currentProgress: "",
        currentInputElement: "",
        onload_status: false,
        upload_status: [],
        reminder: true,
        init: function(count) {
            var _this = this;
            // hidden input element
            var element = $("#fileupload-form-" + count);
            var maxFileSize = 15000000;
            element.fileupload({
                type: "POST",
                autoUpload: true,
                progressInterval: 10,
                maxFileSize: maxFileSize, // 15 MB
                maxSizeOfFiles: maxFileSize, // 15 MB
                sequentialUploads: true,
                dataType: 'json',
                dropZone: '#file_dropzone_' + count,
                url: window.location.origin + '/helpdesk/attachments/1/create_attachment',
                filesContainer: $(".multiple-filelist-" + $(element).data('multifile-count')),
                uploadTemplateId: "upload-template-" + $(element).data('multifile-count'),
                downloadTemplateId: "download-template-" + $(element).data('multifile-count'),
                persist: true
            }).error(function(xhr, textStatus, errorThrown) {
                if (errorThrown === 'abort') {
                    console.log('File Upload has been canceled');
                }
            });
            // on drag
            $("body").on("dragover", function(e) {
                // hide quoted text
                $(".wrap-marker:visible").hide();
                var count = $(".attachment-icon:visible").data('iconCount');
                $("#file_dropzone_" + count).show();
                e.preventDefault();
                e.stopImmediatePropagation();
            });
            // on droping to document
            $("body").on("drop", function(e) {
                // show quoted text
                $(".wrap-marker").show();
                var count = $(".attachment-icon:visible").data('iconCount')
                $("#file_dropzone_" + count).hide();
                e.preventDefault();
                e.stopImmediatePropagation();
            });

            // on drag leav
            $("body").on("dragleave", "#file_dropzone_" + count, function(e) {
                $(".wrap-marker").show();
                var count = $(".attachment-icon:visible").data('iconCount');
                $("#file_dropzone_" + count).hide();
                e.stopImmediatePropagation();
            });
            // on dropping to dropzone
            $("body").on("drop", "#file_dropzone_" + count, function(e) {
                // show quoted text
                $(".wrap-marker").show();
                var count = $(".attachment-icon:visible").data('iconCount');
                $("#file_dropzone_" + count).hide();
                e.stopImmediatePropagation();

            });
            // upload failed - network error
            $("body").on("fileuploadfailed", "#fileupload-form-" + count, function(e, data) {
                errorFile(data, 'Attachment failed due to network error', $(this).data('multifileCount'));
            });
            // upload failed file size
            $("body").on("fileuploadprocessfail", "#fileupload-form-" + count, function(e, data) {
                errorFile(data, 'Attachment failed - file > 15 MB', $(this).data('multifileCount'));
            });
            // error file function
            var errorFile = function(data, message, multifileCount) {
                var $el = $("#file_" + data.files[0].attach_id + "");
                $el.children('i').removeClass('file-remove').removeClass('file-abort');
                $el.addClass("error-file");
                $el.addClass("error");
                $el.attr('title', message);
                $el.children('i').removeClass('ficon-cross').addClass('ficon-notice');
                $('#attach-limt-' + multifileCount).hide();
                // checking for background process 
                if (_this.backgroundProcess['status_' + multifileCount]) {
                    _this.backgroundProcess.execute(0, multifileCount);
                }

            };
            // on upload
            $("body").on("fileuploadadd", "#fileupload-form-" + count, function(e, data) {
                // checking for existing files
                var existing_file_size = 0;
                _this.currentInputElement = $("input[data-input-id='" + $(this).data('multifile-count') + "']");
                var existing = $(_this.currentInputElement).siblings('.existing-file-list').children();

                $.each(existing, function(key, element) {
                    existing_file_size = existing_file_size + $(element).data('fileSize');
                });
                // existing newly attached file size
                var new_attachments_size = $(_this.currentInputElement).data('totalSize');
                // incoming files size
                var file_total = data.files[0].size;
                // for adding random id
                var k = Math.floor(Math.random() * 1000000);
                data.files[0].attach_id = k;
                if (data.files[0].size < maxFileSize) {
                    // adding to queue
                    _this.upload_status.push(k);
                    // total size
                    var total_file_size = existing_file_size + new_attachments_size + file_total;
                    // adding new size to input
                    var new_size = new_attachments_size + file_total;
                    // hide attach limit
                    $("#attach-limt-" + $(this).data('multifileCount')).hide();
                    // creating random id
                    if (total_file_size >= maxFileSize) {
                        _this.upload_status.pop();
                        var value = { name: data.files[0].name, size: data.files[0].size };
                        $("#attachment-template").tmpl({
                            render_type: "error",
                            type: "",
                            files: value
                        }).appendTo(".multiple-filelist[data-filelist-count='" + count + "']");
                        return false;
                    }
                    $(_this.currentInputElement).data('totalSize', new_size);
                    // enabling pjax
                    if (!_this.PjaxSet) {
                        _this.PjaxSet = true;
                        _this.PjaxOn();
                    }
                }
            });
            // on file abort
            $("body").on("click.file_abort", '.file-abort', function(e) {
                // remove aborted file size
                _this.fileAbort();
                e.stopImmediatePropagation();
                // showing attach limit
                if ($('.multiple-filelist-' + count + ' .file-upload').length == 0 && $('.multiple-filelist-' + count + ' .file').length == 0 && $('.existing-file-list[data-count=' + count + ']').children().length == 0) {
                    jQuery("#attach-limt-" + count).show();
                }
            });
            // progress
            $("body").on("fileuploadprogress", "#fileupload-form-" + count, function(e, data) {
                _this.currentProgress = data;
                if (data.files[0].MaxSize) {
                    return false;
                } else {
                    var progress = parseInt(data.loaded / data.total * 100, 10);
                    $("#file_" + data.files[0].attach_id + " #progressBar").css('width', progress + '%');
                }
            });
            // file upload done
            $("body").on("fileuploaddone", "#fileupload-form-" + count, function(e, data) {
                var file = JSON.parse(data.jqXHR.responseText).files[0];
                var form = $('[data-multifile-count="' + $(element).data('multifileCount') + '"]').closest('form');
                var attachId = $(this).data('multifileCount');

                function normal_attachments() {
                    var attachment_form_element = $('input[data-input-id="' + $(element).data('multifileCount') + '"]');
                    if (attachment_form_element.val() === "") {
                        attachment_form_element.val(file.id);
                    } else {
                        attachment_form_element.val(attachment_form_element.val() + ',' + file.id);
                    }
                }
                // removing file from stack
                _this.upload_status.pop();
                // removing pjax 
                if (_this.upload_status.length == 0) {
                    _this.PjaxOff();
                }
                // checking for background proccess
                if (_this.backgroundProcess["enabled_" + attachId] == true && _this.backgroundProcess["status_" + attachId] == true) {
                    // execute background process
                    _this.backgroundProcess.execute(file.id, attachId);
                } else {
                    normal_attachments();
                    if (_this.upload_status.length == 0) {
                        if ($("#attachment-modal-cancel:visible").length == 1) {
                            $("#attachment-modal-cancel:visible").trigger('click');
                            // if edit ticket
                            if(App.namespace == "helpdesk/tickets/edit" || App.namespace == "solution/articles/show") {
                                form.find(".existing-file-list input[name='helpdesk_note[attachments][][resource]']").remove();
                                form.find(".existing-file-list input[name='[cloud_file_attachments][]']").remove();
                            }
                            form.submit();
                            $("#attachment-modal").remove();
                        }
                    }
                }
            });
            // remove 
            $('.multiple-filelist').on("click", ".file-remove", function(e) {
                $(".twipsy").hide();
                $('.tooltip-arrow').parent().hide();
                var count = $(this).closest('.multiple-filelist').data('filelistCount');
                var attachment_form_element = $('input[data-input-id="' + count + '"]');
                if (attachment_form_element.val().indexOf(',') > -1) {
                    attachment_form_element.val(attachment_form_element.val().replace("," + $(this).data('file-id'), ""));
                } else {
                    attachment_form_element.val(attachment_form_element.val().replace($(this).data('file-id'), ""));
                }
                // reducing total 
                attachment_form_element.data('totalSize', attachment_form_element.data('totalSize') - $(this).data('fileSize'));
                $.ajax({
                    url: window.location.origin + $(this).data('delete-url'),
                    type: "delete",
                    error: function(err) {
                        console.log("file removal failed !");
                    }
                });
                $(this).parent('.file').remove();
                if ($('.multiple-filelist-' + count + ' .file').length == 0 && $('.existing-file-list[data-count=' + count + ']').children().length == 0) {
                    jQuery("#attach-limt-" + count).show();
                }
                e.stopImmediatePropagation();
            });

            //   // Enable iframe cross-domain access via redirect option:
            $("#fileupload-form-" + count).fileupload(
                'option',
                'redirect',
                window.location.href.replace(
                    /\/[^\/]*$/,
                    '/cors/result.html?%s'
                )
            );

            // reset's and submit handling 

            var form = $("#fileupload-form-" + count).closest('form');
            $(form).on("reset", function(e) {
                _this.reminder = true;
                var attachment_form_element = $('input[name="attachments_list"]');
                attachment_form_element.val("");
                attachment_form_element.data("total-size", 0);
                $(".attachment-limit").each(function(key, data) {
                    var attachId = jQuery(data).attr('id');
                    attachId = attachId.split('-');
                    if ($(".existing-file-list[data-count='" + attachId[2] + "']").children('.existing-filelist').length == 0) {
                        $(data).show();
                    }
                });
                $(".multiple-filelist").html("");
                e.stopImmediatePropagation();
            });

            form.on("submit", function(event) {
                // turning of reminder
                _this.reminder = false;
                // preventing from edit note
                function normal_attachments() {
                    if ($('#attachment-modal').length == 0) {
                        $("body").append('<div id="attachment-modal"><div class="progressHolder" style="" id="modalProgressBar"><div class="progress-bar progress-bar-striped active" style="width:100%;height:10px;position:relative;"></div></div><a href="#" data-dismiss="modal" class="btn btn-primary pull-right" id="attachment-modal-cancel">Hide</a></div>');
                    }
                    var data = {
                        targetId: "#attachment-modal",
                        title: _this.message.progress_modal_header,
                        width: "400",
                        submitLabel: "Ok",
                        showClose: "true",
                        closeLabel: "Hide",
                        destroyOnClose: true,
                        templateFooter: "false",
                    }
                    $.freshdialog(data);
                }
                if (_this.upload_status.length !== 0) {
                    // if background process enabled
                    if (typeof TICKET_DETAILS_DATA !== "undefined") {
                        var attachId = $(this).find('.fileupload-form').data('multifileCount');
                        if (_this.backgroundProcess["enabled_" + attachId]) {
                            // checking form forward 
                            if ($(form).data('cntId') == "cnt-fwd") {
                                if ($(".forward_email .multi_value_field .choice").length == 0) {
                                    return;
                                }
                            }
                            window.form = form;
                            _this.backgroundProcess.create_pool(form, attachId);
                            _this.PjaxOff();
                            var submitBtn = form.find('.submit_btn');
                            submitBtn.data('prevText', submitBtn.text()).text(_this.message.sending);
                            form.append('<div class="blockUI blockOverlay attach-block-ui" style="z-index: 1000; border: none; margin: 0px; padding: 0px; width: 100%; height: 100%; top: 0px; left: 0px; opacity: 0.6; cursor: wait; position: absolute; background-color: rgb(233, 233, 233);"></div>');
                        } else {
                            normal_attachments();
                        }

                        event.preventDefault();
                        event.stopImmediatePropagation();
                        return false;
                    }
                    // if not
                    else {
                        normal_attachments();
                        event.preventDefault();
                        event.stopImmediatePropagation();
                        return false;
                    }

                }
                // if edit note form ---- reseting edit note form
                var noteId = $(form).find(".attachment-options-reply").data('noteId') || 0;
                if (noteId !== 0) {
                    $('.editNoteCancelButton').trigger('click');
                }
                // maintaining attach limit
                var elist = $(form).find('.existing-file-list').children().length;
                var nlist = $(form).find('.multiple-filelist').children().length;
                if (elist == 0 && nlist == 0) {
                    $(form).find('.attachment-limit').show();
                }
                // if edit ticket
                if(App.namespace == "helpdesk/tickets/edit" || App.namespace == "solution/articles/show") {
                    form.find(".existing-file-list input[name='helpdesk_note[attachments][][resource]']").remove();
                    form.find(".existing-file-list input[name='[cloud_file_attachments][]']").remove();
                }
            });
            // calling onload functions
            if (_this.onload_status == false) {
                _this.onload();
                _this.onload_status = true;
            }
        },
        // file abort function 
        fileAbort: function() {
            var _this = this;
            _this.upload_status.pop();
            // pajax off 
            if (_this.upload_status.length == 0) {
                _this.PjaxOff();
            }
            var updated_size = $(_this.currentInputElement).data('totalSize') - Helpdesk.MultipleFileUpload.currentProgress.files[0].size;
            $(_this.currentInputElement).data('totalSize', updated_size);
            // abort
            _this.currentProgress.abort();
            _this.currentProgress.xhr().abort();
            return "done";
        },
        // --------------------- Background proccess starts here ---- 
        backgroundProcess: {
            pool: [],
            parent: this.Helpdesk,
            // setting background proccess enabled and status
            init: function(attachId, bEnabled) {
                this['enabled_' + attachId] = bEnabled;
                this['status_' + attachId] = false;
            },
            create_pool: function(form, attachId) {
                // adding entry to background pool
                this['status_' + attachId] = true;
                this.pool.push({ pId: attachId, tId: TICKET_DETAILS_DATA.displayId, href: window.location.href, hash: form.serializeObject(), form: form, remaining: this.parent.MultipleFileUpload.upload_status.length });
                this.parent.MultipleFileUpload.upload_status = [];
                // adding a hidden dom to body
                if (jQuery(".attachment-backgroundProcess-container").length == 0) {
                    jQuery("body").append('<div class="attachment-backgroundProcess-container hide"></div>');
                }
                // creating input reference
                this.input = jQuery(form).find('#fileupload-form-' + attachId);
                var parent = this.input.parent();
                var detachEl = this.input.detach();
                var clonedInput = this.input.clone(true);
                jQuery(".attachment-backgroundProcess-container").append(detachEl);
                jQuery(parent).append(clonedInput);
            },
            execute: function(fileId, attachId) {
                var _this = this;
                var attachIndex = "";
                this.pool.each(function(a, index) {
                    if (a.pId == attachId) {
                        attachIndex = index;
                        return;
                    }
                });
                if (fileId !== 0) {
                    if (_this.pool[attachIndex].pId == attachId) {
                        // adding file id to the hash
                        if (_this.pool[attachIndex].hash.attachments_list.length == 0) {
                            _this.pool[attachIndex].hash.attachments_list = fileId;
                        } else {
                            _this.pool[attachIndex].hash.attachments_list = _this.pool[attachIndex].hash.attachments_list + "," + fileId;
                        }
                    }
                }
                _this.pool[attachIndex].remaining = _this.pool[attachIndex].remaining - 1;
                if (_this.pool[attachIndex].remaining == 0) {
                    jQuery(_this.pool[attachIndex].form).find('input[name="attachments_list"]').val(_this.pool[attachIndex].hash.attachments_list);
                    var origin = _this.pool[attachIndex].href;
                    var tktId = _this.pool[attachIndex].tId;
                    _this.lastform = $("#fileupload-form-" + attachId).closest('form');
                    // normal submit if in same tkt page
                    if (window.location.href == origin) {
                        var SubmitCallback = function() {

                            var form = _this.lastform;
                            var submitBtn = form.find('.submit_btn');
                            submitBtn.text(submitBtn.data('prevText'));
                            // removing block ui
                            Helpdesk.MultipleFileUpload.reminder = true;
                            $(".attach-block-ui").remove();

                        }
                        submitNewConversation(_this.pool[attachIndex].form, "", SubmitCallback);
                    } else {
                        // submitting form  
                        _this.xhr = $.ajax({
                            url: _this.pool[attachIndex].form.attr('action'),
                            type: "post",
                            data: _this.pool[attachIndex].hash,
                            persist: true,
                            success: function(data) {
                                Helpdesk.MultipleFileUpload.reminder = true;
                            },
                            error: function() {
                                var template = '<div style="" class="sending-failed-template">' + _this.parent.MultipleFileUpload.message.sending_failed + ' <a href="/helpdesk/tickets/' + tktId + '" data-pjax="#body-container" onClick="Helpdesk.MultipleFileUpload.backgroundProcess.removeTemplate()" >' + _this.parent.MultipleFileUpload.message.try_again + '</a> <i class="ficon-cross" onClick="Helpdesk.MultipleFileUpload.backgroundProcess.removeTemplate()"></i></div>';
                                $("body").append(template);
                                setTimeout(function() {
                                    Helpdesk.MultipleFileUpload.backgroundProcess.removeTemplate();
                                }, 10000);
                            }
                        });
                    }
                    _this['status_' + attachId] = false;
                    _this.pool.splice(attachIndex, 1);
                }
            },
            removeTemplate: function() {
                $(".sending-failed-template").remove();
            }
        },
        canned_response: function(data, count) {
            $("#attach-limt-" + count).hide();
            $("#attachment-template").tmpl({
                render_type: "new",
                type: "canned_response",
                files: data,
            }).appendTo(".multiple-filelist-" + count);
        },
        // --------------- PJAX configurations ------
        PjaxSet: false,
        PjaxOn: function() {
            var _this = this;
            if (_this.upload_status.length !== 0) {
                if (App.namespace == "helpdesk/tickets/show" && jQuery(".attach-block-ui:visible").length !== 0) {
                    return;
                } else {
                    this.PjaxSet = true;
                    jQuery(window).on("pjax:beforeSend.attachments-pjax", function(event) {
                        // check again
                        var c = confirm(_this.message.in_progress);
                        if (!c) {
                            event.preventDefault();
                        } else {
                            _this.PjaxOff();
                        }
                    });
                }
            }
        },
        PjaxOff: function() {
            this.PjaxSet = false;
            jQuery(window).off('.attachments-pjax');
        },
        onload: function() {
            var _this = this;
            // on window unload
            $(window).on("beforeunload", function(e) {
                if (_this.upload_status.length !== 0 || _this.backgroundProcess.pool.length !== 0) {
                    return "Discard file uploads ?";
                }
            });
            $("body").on("click", '.attachment-icon', function(e) {
                if ($(this).data('integration')) {
                    window.localStorage.setItem("current-file-list", $(this).data('iconCount'));
                }
            });
            // error file removal
            $("body").on("mouseover", ".error-file", function() {
                $(this).children('i').removeClass('ficon-notice').addClass('ficon-cross');
            });
            $("body").on("mouseout", ".error-file", function() {
                $(this).children('i').removeClass('ficon-cross').addClass('ficon-notice');
            });
            $("body").on("click", ".error-file .file-close", function() {
                $(this).parent().remove();
                $(".twipsy").hide();
                $('.tooltip-arrow').parent().hide();

            });
            // delete action for  - existing file upload
            $('body').on("click", ".existing-filelist .file-close , .existing-filelist-cloud .file-close", function() {
                var c = confirm(_this.message.permanent_delete);
                var element_this = $(this);
                if (c) {
                    if (element_this.data('cloudFile')) {
                        var deleteUrl = window.location.origin + "/helpdesk/cloud_files/" + $(this).data('attachId');
                        if (App.namespace == "solution/articles/show") {
                            deleteUrl = window.location.origin + "" + App.Solutions.Article.data.draftDiscardUrl.replace('/delete', "") + "/cloud_file/" + $(this).data('attachId') + "/delete";
                        }
                        // if forward delete
                         if (element_this.data('softdelete') == true) {
                            Ajaxsuccess();
                            return;
                        }
                        function Ajaxsuccess() {
                            $(".twipsy").hide();
                            $('.tooltip-arrow').parent().hide();
                            element_this.parent().parent().remove();
                            // for data manage in note
                            var drop_id = element_this.closest('.attachment-options-reply').data();
                            if ($('.attachment-names:visible').data('note') === true) {
                                Helpdesk.MultipleFileUpload.manageNoteData("cloud_file", element_this.data('attachId'), drop_id);
                                $("#helpdesk_attachment_" + element_this.data('attachId')).remove();
                            }
                        }

                        $.ajax({
                            url: deleteUrl,
                            type: "delete",
                            dataType: "script",
                            success: function(data) {
                                Ajaxsuccess();
                            },
                            error: function(data) {
                                Ajaxsuccess();
                                console.log("delete failed cloud file!");
                            }
                        });
                    } else {
                        var deleteUrl = window.location.origin + "/helpdesk/attachments/" + element_this.data('attachId') + "/delete_attachment";
                        if (App.namespace == "solution/articles/show") {
                            deleteUrl = window.location.origin + "" + App.Solutions.Article.data.draftDiscardUrl.replace('/delete', "") + "/attachment/" + element_this.data('attachId') + "/delete";
                        }
                        // forward file deletion
                        if (element_this.data('softdelete') == true) {
                            Ajaxsuccess();
                            return;
                        }

                        function Ajaxsuccess() {
                            $(".twipsy").hide();
                            $('.tooltip-arrow').parent().hide();
                            element_this.parent().parent().remove();
                            // for data manage in note
                            if ($('.attachment-names:visible').data('note') == true) {
                                Helpdesk.MultipleFileUpload.manageNoteData("attachment", element_this.data('attachId'), 0);
                                $("#helpdesk_attachment_" + element_this.data('attachId')).remove();
                            }
                        }
                        $.ajax({
                            url: deleteUrl,
                            type: "delete",
                            dataType: "script",
                            success: function(data) {
                                Ajaxsuccess();
                            },
                            error: function(data) {
                                Ajaxsuccess();
                                console.log("Deleting Failed !");
                            }
                        });
                    }
                }

            });
            // removing cloud files and canned response
            $("body").on("click", ".new-cloud-file .file-close ", function() {
                $(".twipsy").hide();
                $('.tooltip-arrow').parent().hide();
                var count = $(this).parent().parent().data('filelist-count');
                $(this).parent().remove();
                if ($('.multiple-filelist-' + count + ' .file').length == 0 && $('.existing-file-list[data-count=' + count + ']').children().length == 0) {
                    jQuery("#attach-limt-" + count).show();
                }
            });

            // for edit note - ticket details
            $("body").on("click", ".conv-actions-edit", function() {
                var noteId = $(this).attr('noteid');
                var containerElement = $("div[data-attachment-noteid='" + noteId + "']");
                var Appendelement = $("#helpdesk_note_" + noteId + " .existing-file-list");
                var timer;
                // if there is no container
                if (containerElement.length == 0)
                    return;
                var render = function() {
                    Appendelement = $("#helpdesk_note_" + noteId + " .existing-file-list");
                    if (Appendelement.length !== 0) {
                        clearInterval(timer);
                        // hide existing attachments
                        $("#note_attachments_container_" + noteId).hide();
                        // attachment limit remove
                        if (($(containerElement).data('attachments').length != 0) || ($(containerElement).data('cloudfile').length != 0)) {
                            $("#helpdesk_note_" + noteId + " .attachment-limit").hide();
                        }
                        // to template
                        $("#attachment-template").tmpl({
                            render_type: "existing",
                            type: "attachment",
                            files: $(containerElement).data('attachments'),
                            template:false,
                            softdelete: false,
                        }).appendTo("#helpdesk_note_" + noteId + " .existing-file-list");
                        // cloud files
                        $("#attachment-template").tmpl({
                            render_type: "existing",
                            type: "cloud",
                            files: $(containerElement).data('cloudfile'),
                            template:false,
                            softdelete: false,
                        }).appendTo(Appendelement);
                    }
                    _this.backgroundProcess.enabled = false;
                };
                // a function to wait for dom to append
                function waitor() {
                    if (Appendelement.length == 0) {
                        timer = window.setInterval(render, 1000);
                    } else {
                        render();
                    }
                };
                waitor();

            });
            // on cancel
            $("body").on("click", ".editNoteCancelButton", function() {
                _this.backgroundProcess.enabled = true;
                var noteId = $(this).attr('noteid');
                $("#helpdesk_note_" + noteId + " .existing-file-list").html("");
                $("#note_attachments_container_" + noteId).show();
            });
            // on update
            $("body").on("click", '.editNoteUpdateButton', function() {
                if (_this.upload_status.length == 0) {
                    var noteId = $(this).attr('noteid');
                    $("#helpdesk_note_" + noteId + " .existing-file-list").html("");
                    $("#note_attachments_container_" + noteId).show();
                }

            });
            // for abort background process 
            $("body").on("click", "#bg-process-abort", function(e) {
                e.preventDefault();
                _this.backgroundProcess.abort();
            });
            //bulk actions
            var preventable_areas = [".bulk_action_buttons a.btn", ".bulk_action_buttons input.btn", ".tkt-details-sticky .reload-action"];
            preventable_areas.map(function(a) {
                jQuery("body").on("click", a, function(e) {
                    if (Helpdesk.MultipleFileUpload.backgroundProcess.pool.length !== 0) {
                        alert(_this.message.actions_alert);
                        e.preventDefault();
                        e.stopImmediatePropagation();
                        return;
                    }
                });
            });
            // reminder
            // jQuery(window).on("pjax:beforeSend.attachment-reminder", function(event) {
            //     if (jQuery(".multiple-filelist .file").length !== 0 && _this.upload_status.length == 0 && jQuery(".attach-block-ui:visible").length == 0) {
            //         if(_this.reminder) {
            //             var c = confirm(_this.message.reminder);
            //             if (!c) {
            //                 event.preventDefault();
            //                 event.stopImmediatePropagation();
            //                 return;
            //             }
            //         }
            //     }
            // });
            // jQuery(window).on("beforeunload", function() {
            //     if (jQuery(".multiple-filelist .file").length !== 0) {
            //         if(_this.reminder) {
            //             return _this.message.reminder;
            //         }
            //     }
            // });

        },

        // ** global functions **

        // function for template
        FilenameSplitter: function(fullname) {
            var re = /(.+?)(\.[^.]*$|$)/;
            var m;
            if ((m = re.exec(fullname)) !== null) {
                if (m.index === re.lastIndex) {
                    re.lastIndex++;
                }
            }
            return {
                fname: m[1],
                type: m[2].replace('.', '')
            };
        },
        // file size calculator
        formatFileSize: function(bytes) {
            if (typeof bytes !== 'number') {
                return '';
            }
            if (bytes >= 1000000000) {
                return (bytes / 1000000000).toFixed(2) + ' GB';
            }
            if (bytes >= 1000000) {
                return (bytes / 1000000).toFixed(2) + ' MB';
            }
            return (bytes / 1000).toFixed(2) + ' KB';
        },
        // file obj convertor
        fileObjectConvertor: function(obj) {
            var attachments = JSON.stringify({
                link: obj.url,
                name: obj.filename,
                original_attachment: true,
                provider: obj.provider,
            });
            return attachments;
        },
        // render existing files
        renderExistingFiles: function(attachments, cloudfile, count, template, nscname,softdelete) {
           
            // for changing ticket templates nsc param
            if (typeof template == "undefined") {
                template = false;
            }
            if (typeof nscname == "undefined") {
                nscname = null;
            }
            // softdelete
            if (softdelete == "undefined") {
                softdelete = false;
            }
            // attachment limit remove
            if ((attachments.length !== 0) || (cloudfile.length !== 0)) {
                $("#attach-limt-" + count + "").hide();
            }
            $("#attachment-template").tmpl({
                render_type: "existing",
                type: "attachment",
                files: attachments,
                template: template,
                nscname: nscname,
                softdelete: softdelete,
            }).appendTo(".existing-file-list[data-count='" + count + "']");
            // cloud files
            $("#attachment-template").tmpl({
                render_type: "existing",
                type: "cloud",
                files: cloudfile,
                template: template,
                nscname: nscname,
                softdelete: softdelete,
            }).appendTo(".existing-file-list[data-count='" + count + "']");
        },
        //on  note attachment delete
        manageNoteData: function(type, id, drop_id) {
            if (type == "attachment") {
                var container = $("#helpdesk_attachment_" + id).parent().parent();
                var attachments = $(container).data('attachments');
                $(container).data('attachments', attachments.filter(function(a) {
                    return a.id !== id;
                }));
                this.manage_counts(container);

            }
            if (type == "cloud_file") {
                var container = $('.attachments-wrap[data-attachment-noteid="' + drop_id + '"]');
                var attachments = $(container).data('cloudfile');
                $(container).data('cloudfile', attachments.filter(function(a) {
                    return a.cloud_file.id !== id;
                }));
                this.manage_counts(container);
            }



        },
        manage_counts: function(container) {
            // managing counts
            var re = /(\d+) (\w+.*)/;
            var str = $(container).children('h5').children('strong').text();
            var m;
            if ((m = re.exec(str)) !== null) {
                if (m.index === re.lastIndex) {
                    re.lastIndex++;
                }
            }
            var newCount = parseInt(m[1]) - 1;
            if (newCount > 0) {
                newCount = newCount + ' ' + m[2];
                $(container).children('h5').children('strong').text(newCount);
            } else {
                $(container).children('h5').children('strong').text('');
            }
        }
    };

}(jQuery));

//Ticket page sticky active handler
Helpdesk.TicketStickyBar = {
    active_handler_ele: ['reply', 'fwd', 'note'],
    // checks for current open redactor box
    check: function() {
        this.removeActive();
        var ele = jQuery(".cancel_btn[data-cnt-id]:visible").data('cntId');
        if (typeof ele !== "undefined") {
            jQuery("[data-domhelper-name='" + ele.split('-')[1] + "-sticky-button']").addClass('active');
        }
    },
    // binding events
    bindEvents: function() {
        var _this = this;
        jQuery("body").on("click", "#sticky_header a[data-domhelper-name]", function() {
            _this.removeActive();
        });
        this.active_handler_ele.map(function(ele) {
            // click event binding
            jQuery("body").on("click", "a[data-note-type='" + ele + "']", function() {
                jQuery("[data-domhelper-name='" + ele + "-sticky-button']").addClass('active');
            });
            // cancel event binding
            jQuery("body").on("click", ".cancel_btn[data-cnt-id='cnt-" + ele + "']", function(e) {
                jQuery("[data-domhelper-name='" + ele + "-sticky-button']").removeClass('active');
            });
            // sticky bar action
            jQuery("body").on("click", ".active[data-domhelper-name='" + ele + "-sticky-button']", function(e) {
                jQuery(this).removeClass("active");
                jQuery(".cancel_btn[data-cnt-id='cnt-" + ele + "']").trigger('click');
                e.stopImmediatePropagation();
            });
        });
    },
    // removes .active class from all sticky elements
    removeActive: function() {
        jQuery.each(jQuery("#sticky_header a.active[data-domhelper-name]"), function(key, data) {
            jQuery(data).removeClass('active');
        });
    },
    // invokes all functions
    init: function() {
        this.bindEvents();
        this.check();
    }
};
jQuery(document).ready(function() {
    Helpdesk.TicketStickyBar.init();
});

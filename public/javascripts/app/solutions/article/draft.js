/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    autosaveInitialize: function (data) {
      data = data || $('#article-form').data();
      var draft_options = {
        autosaveInterval: 5000,
        autosaveUrl: data.autosavePath,
        monitorChangesOf: {
          description: "#solution_article_description",
          title: "#solution_article_title"
        },
        extraParams: {timestamp: data.timestamp},
        minContentLength: 3,
        retryIfError: false,
        responseCallback: $.proxy(this.autosaveDomManipulate, this)
      };

      this.autoSave = $.autoSaveContent(draft_options);
    },

    resetDraftRequest: function () {
      $('#cancel_draft_changes_input').prop('disabled', false);
      var new_draft_record = ($("#last-updated-at").length === 0);
      //request for submitting serialized form if a draft already existed
      var form_submit = {
          type: 'POST',
          url: $('.article-edit-form').get(0).action,
          data: $('.article-edit-form').serialize(),
          dataType: "script"
        },
        //request for discarding draft if a draft didn't exist initially
        draft_discard = {
          type: 'DELETE',
          url: $('.article-edit-form').data().draftDiscardUrl,
          dataType: "script"
        },
        handlers = {},
        request = $.extend({}, handlers, (new_draft_record ? draft_discard : form_submit));

      //Only if a single autosave is success should we reverse the changes done
      if (this.autoSave.successCount > 0) {
        $.ajax(request);
      }

      if (new_draft_record) {
        $('#sticky_redactor_toolbar').removeClass('has-notification');
      }
      
    },

    autosaveDomManipulate: function (response) {
      var $this = this;
      var changeDom = {
        mainElement: $(".draft-notif"),
        msgElement: $(".autosave-notif"),
        lastSuccess: false,
        liveTimeStamp: function () {
          var ts = Math.round((new Date()).getTime() / 1000);
          return $('<span />').attr('data-livestamp', ts)
                    .attr("title", moment().format('ddd, Do MMMM [at] h:mm A'))
                    .addClass('tooltip');
        },
        reloadButton: function () {
          return $('<span />').attr('onclick', 'window.location.reload();').
            html($this.STRINGS.reload).attr('class', 'btn btn-small reload-btn');
        },
        backButton: function () {
          return $('<a>').attr('href', "/solution/categories").
            html($this.STRINGS.back).attr('class', 'btn btn-small back-btn').attr("data-pjax", "#body-container");
        },
        message: function (msg, success) {
          return $('<span />').html(msg).attr('class', (success ? "" : "delete-confirm-warning-icon"));
        },
        htmlToStr: function (element) {
          return element.wrap('<div/>').parent().html();
        },
        themeChange: function (isError) {
          this.msgElement
            .toggleClass('error', isError)
            .show();
        },
        lastUpdatedAt: function (response) {
          if (response.timestamp) {
            $("#last-updated-at").val(response.timestamp);
          }
        },
        toggleButtons: function (flag) {
          var $flag = flag;
          $.each(['.cancel-button', '#save-as-draft-btn', '.btn-primary', '#save-btn'], function (index, el) {
            $(el).prop('disabled', !$flag);
          });
          $('.confirm-delete').attr('disabled', !$flag);
        },
        disableViewOnPortal: function (flag) {
          $('.portal-preview-icon a, .portal-preview-icon a i').toggleClass('disabled', flag);
        },
        previewDrafts: function () {
          var data = $('#article-form').data();
          if(data) {
            return $('<span />').attr('class', 'pull-right')
                  .html($('<a>').attr('href', data.previewPath).attr('target', "draft-" + data.articleId)
                  .text(data.previewText));
          } else {
            return $('<span />');
          }
        },
        manipulate: function (response, success) {
          var content = "";
          var deleted = response.deleted || false;
          response = response || { msg: $this.STRINGS.somethingWrong};
          if (deleted){ response = { msg: $this.STRINGS.articleDeleted }; }
          if (response.msg) {
            content = this.htmlToStr(this.message(response.msg, success));
            content += this.htmlToStr(success ? this.liveTimeStamp() : deleted ? this.backButton() : this.reloadButton());
            content += deleted ? "" : this.htmlToStr(this.previewDrafts());
            this.msgElement.html(content).filter(':hidden').show();
            $('.article-view-edit:visible').hide();
            this.themeChange(!success);
            this.lastUpdatedAt(response);
            this.toggleButtons(success);
            $('#sticky_redactor_toolbar').addClass('has-notification');
            this.disableViewOnPortal(deleted);
          }
        }

      };

      if (typeof (response) === 'object' && response.success) {
        changeDom.manipulate(response, true);
      } else {
        this.autoSave.lastSaveStatus = false;
        changeDom.manipulate(response, false);
      }
      this.autoSave.contentChanged = !response.success;
    }
  });
}(window.jQuery));
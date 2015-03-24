/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {

    onVisit: function (data) {
      if (App.namespace === "solution/articles/new") {
        this.eventsForNewPage();
      } else if (App.namespace === "solution/articles/show") {
        this.showPage();
      }
    },

    bindHandlers: function () {
    },

    onLeave: function (data) {
      $('body').off('.articles');
    },

    eventsForNewPage: function () {
      this.bindPropertiesToggle();
      this.formatSeoMeta();
      this.select2Tags();
    },
    
    bindPropertiesToggle: function () {
      $('body').on('click.articles', '#solution-properties-show', function (ev) {
        var visiblility = $('#solution-properties').is(":visible");
        $('#show-hide-button')
          .toggleClass("arrow-right", visiblility)
          .toggleClass("arrow-down", !visiblility);
        $('#solution-properties').toggle('fast', function () {});
      });
    },

    select2Tags: function () {
      $("#tags_name").select2({
        tags: $("#tags_name").data('tags').split(","),
        tokenSeparators: [',']
      });
    },

    formatSeoMeta: function () {
      $('body').on('click.articles', '#article-form', function (ev) {
        $('#solution_article_seo_data_meta_description').val(
          $('#solution_article_seo_data_meta_description').val().replace(/\n+/g, " ").trim()
        );
      });
    },

    cancelDraft: function () {
      var $this = this;
      $("#edit-cancel-button").bind('click', function () {
        $(".article-edit-form")[0].reset();
        $(".redactor_editor").html($("#solution_article_description").val());
        $this.articleDraftAutosave.contentChanged = false;
      });
    },

    autosaveInitialize: function (data) {
      var draft_options = {
        autosaveInterval: 5000,
        autosaveUrl: data.autosavePath,
        monitorChangesOf: {
          description: ".redactor_editor",
          title: "#solution_article_title"
        },
        extraParams: {timestamp: data.timestamp},
        responseCallback: this.autosaveDomManipulate
      };

      this.articleDraftAutosave  = $.autoSaveContent(draft_options);
      this.cancelDraft();
      this.unsavedContentNotif();
      this.attachmentAutosaveTrigger();
      return this.articleDraftAutosave;
    },

    attachmentAutosaveTrigger: function () {
      var $this = this;
      $(".hidden_upload").on('change.articles', function () {
        if ($this.articleDraftAutosave.successCount > 0) {
          $(".hidden_upload").unbind('change.articles');
        } else {
          $this.articleDraftAutosave.getContent();
        }
      });
    },

    autosaveDomManipulate: function (response) {

      var changeDom = {
        mainElement: $(".draft-info-box"),
        msgElement: $(".autosave-notif"),
        liveTimeStamp: function () {
          var ts = Math.round((new Date()).getTime() / 1000);
          return $('<span />').attr('data-livestamp', ts);
        },
        timeStamp: function () {
          return $('<span />').html(" (" + moment().format('ddd, Do MMMM [at] h:mm A') + ")");
        },
        reloadButton: function () {
          return $('<span />').attr('onclick', 'window.location.reload();').
            html("Reload").attr('class', 'btn btn-small reload-btn');
        },
        message: function (msg, success) {
          return $('<span />').html(msg).attr('class', (success ? "" : "delete-confirm-warning-icon"));
        },
        htmlToStr: function (element) {
          return element.wrap('<div/>').parent().html();
        },
        themeChange: function (isError) {
          this.mainElement
            .toggleClass('error', isError)
            .toggleClass('success', isError)
            .show();
        },
        lastUpdatedAt: function (response) {
          if(response.timestamp){
            $("#last-updated-at").val(response.timestamp);
          }
        },
        manipulate: function (response, success) {
          var content = "";
          if (response.msg) {

            content = this.htmlToStr(this.message(response.msg, success));
            content += success ? (this.htmlToStr(this.liveTimeStamp()) + this.htmlToStr(this.timeStamp())) : this.htmlToStr(this.reloadButton());
            this.msgElement.html(content).show();
            this.themeChange(!success);
            this.lastUpdatedAt(response);
          }
        }
      };


      if (typeof (response) === 'object') {
        if (response.success) {
          changeDom.manipulate(response, true);
        } else {
          changeDom.manipulate(response, false);
        }
      } else {
        changeDom.manipulate({ msg: "Something is wrong."}, false);
      }
    },

    showPage: function () {
      if ($("#folder-section").height() > $("#article-section").height()) {
        $("#article-section").css("minHeight", $("#folder-section").height());
      }
      highlight_code();
    },

    articleProperties: function () {
      var $this = this;
      setTimeout(function () {
        $this.formatSeoMeta();
        $this.select2Tags();
        $("#article-properties-cancel").bind("click", function () {
          $('#article-properties-content #article-form').resetForm();
          $('#article-properties-content #article-form .select2').trigger('change');
        });
      }, 50);
    },

    unsavedContent: function () {
      return (this.articleDraftAutosave.contentChanged || ($(".hidden_upload input").length > 1));
    },

    unsavedContentNotif: function () {
      var $this = this;

      $(window).on('beforeunload.articles', function (e) {
        if ($this.unsavedContent()) {
          var msg = "You have unsaved content in this page.";
          e = e || window.event;
          if (e) {
            e.returnValue = msg;
          }
          return msg;
        }
      });

      $('body').on('submit.articles', '.article-edit-form', function () {
        $(window).off('beforeunload.articles');
      });

      $(document).on('pjax:beforeSend', function (event, xhr, settings, options) {
        if ($this.unsavedContent()) {
          if (!confirm('You have unsaved content in this page. Do you want to leave this page?')) {
            Fjax.resetLoading();
            return false;
          }
        }
      });
    }

  };
}(window.jQuery));
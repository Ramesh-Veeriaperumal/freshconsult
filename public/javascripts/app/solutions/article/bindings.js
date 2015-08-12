/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    showPageBindings: function () {
      var $this = this;
      this.articleHistoryEllipsisExpand();

      this.bindForCancelBtn();
      this.bindForEditBtn();

      this.dummyActionButtonTriggers();
      if (this.data.defaultFolder) {
        this.defaultFolderValidate();
      }
      this.modalBindings();
    },

    modalBindings: function () {
      var $this = this;
      $('body').on('modal_loaded.articles', function () {
        $this.articleTags = $('#tags_name').val();
        $this.articleTags = $this.articleTags != "" ? $this.articleTags.split(",") : "";
        $this.setTagSelector();
        $this.articleProperties();
      });
    },

    bindForEditBtn: function () {
      var $this = this;
      $('body').on('click.articles', '.article-edit-btn', function () {
        $this.startEditing();
        $('.info-data').remove();
      });
    },

    dummyActionButtonTriggers: function () {
      $('body').on('click.articles', '#save-btn, #publish-btn', function () {
        var targetBtn = $(this).data().targetBtn;
        $(targetBtn).trigger('click');
      });
    },

    articleHistoryEllipsisExpand: function() {
      $('body').on('click.articles', '.article-history .ellipsis', function () {
        $('.created-history').toggleClass('hide');
        $('.article-history .ellipsis').toggleClass('hide');
      });
    },

    attachmentsDelEvents: function () {
      $(document).on('attachment_deleted', function(ev, data){
        $(".article-view #helpdesk_" + data.attachment_type + "_" + data.attachment_id).remove();
        $(".article-edit #helpdesk_" + data.attachment_type + "_" + data.attachment_id).fadeOut(500, function(){ $(this).remove(); });
      });
    },

    bindPropertiesToggle: function () {
      $('body').on('click.articles', '#solution-properties-show', function (ev) {
        var visiblility = $('#solution-properties-seo').is(":visible");
        $('#show-hide-button')
          .toggleClass("arrow-right", visiblility)
          .toggleClass("arrow-down", !visiblility);
        $('#solution-properties-seo').toggle('fast', function () {});
      });
    },

    formatSeoMeta: function () {
      $('body').on('submit.articles', '#article-form', function (ev) {
        $('#solution_article_seo_data_meta_description').val(
          $('#solution_article_seo_data_meta_description').val().replace(/\n+/g, " ").trim()
        );
      });
    },

    bindForCancelBtn: function () {
      var $this = this;
      $("body").on('click.articles', "#edit-cancel-button", function (ev) {
        ev.preventDefault();
        $this.cancel_UI_toggle();
        $this.editUrlChange(false);
        $this.autoSave.stopSaving();
        $(".article-edit-form")[0].reset();

        if($this.autoSave.totalCount > 0) {
          $this.setFormValues();
          $this.resetDraftRequest();
          $this.autoSave.contentChanged = false;
          $this.autoSave.totalCount = 0;
          $this.autoSave.successCount = 0;
          $this.autoSave.failureCount = 0; 
        }
      });
    },

    articleProperties: function () {
      var $this = this;
      this.formatSeoMeta();
      $("#article-prop-cancel").bind("click", function () {
        $('#article-prop-content #article-form').resetForm();
        $('.article-tags').select2('val', $this.articleTags);
      });
    },

    formValidate: function () {
      var $this = this;
      $('body').on('submit.articles', '.article-edit #article-form', function (ev) {
        var validation = $('#article-form').valid();
        if (validation) {
          if (!$.isEmptyObject($this.autoSave)) {
            $this.autoSave.stopSaving();
          }
          $(window).off('beforeunload.articles');
        }
        return validation;
      });
    },

    unsavedContentNotif: function () {
      var $this = this;

      $(window).on('beforeunload.articles', function (e) {
        if ($this.unsavedContent()) {
          var msg = $this.STRINGS.unsavedContent;
          e = e || window.event;
          if (e) { 
            e.returnValue = msg;
          }
          return msg;
        }
      });

      $(document).on('pjax:beforeSend.articles', function (event, xhr, settings, options) {
        if ($this.unsavedContent()) {
          if (!confirm($this.STRINGS.unsavedContent + " " + $this.STRINGS.leaveQuestion)) {
            Fjax.resetLoading();
            return false;
          }
        }
      });
    },

    defaultFolderValidate: function () {
      $('body').on('click.articles', '#article-publish-btn, #save-as-draft-btn', function () {
        if ($("#article-form").data().defaultFolder) {
          if ($('#solution_article_folder_id').val() === "") {
            $('.folder-warning-msg').show();
            $('#solution_article_folder_id').select2('focus');
            return false;
          }
        }
        return true;
      });
    },

    setTagSelector: function () {
      var $this = this;
      var previouslyselectedTags = [];
      $('.article-tags').val().split(',').each(function (item, i) { previouslyselectedTags.push({ id: item, text: item }); });
      $('.article-tags').select2({
        multiple: true,
        maximumInputLength: 32,
        data: previouslyselectedTags,
        quietMillis: 500,
        tags: true,
        tokenSeparators: [','],
        ajax: {
          url: '/search/autocomplete/tags',
          dataType: 'json',
          data: function (term) {
            return { q: term };
          },
          results: function (data) {
            var results = [];
            $.each(data.results, function (i, item) {
              var result = escapeHtml(item.value);
              results.push({ id: result, text: result });
              window.results = results;
            });
            return { results: results };

          }
        },
        initSelection : function (element, callback) {
          callback(previouslyselectedTags);
        },
        formatInputTooLong: function () {
          return $this.STRINGS.maxInput;
        },
        createSearchChoice: function (term, data) {
          if ($(data).filter(function () { return this.text.localeCompare(term) === 0; }).length === 0)
          return { id: term, text: term };
        }
      });
    }
  });
}(window.jQuery));
/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    showPageBindings: function () {
      var $this = this;
      this.articleHistoryEllipsisExpand();
      this.cumulativeStatsToggle();

      this.bindForCancelBtn();
      this.bindForEditBtn();

      this.dummyActionButtonTriggers();
      this.modalBindings();
      this.outdateOrUpdate();
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
        $('.breadcrumb').addClass('breadcrumb-edit');
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

    cumulativeStatsToggle: function() {
      $('body').on('click.articles', '.analytics .show-cumulative-stats', function () {
        $('.analytics .cumulative-stats').toggleClass('hide');
        $('.analytics .show-cumulative-stats').toggleClass('drop-right');
        $('.analytics .show-cumulative-stats').toggleClass('selected');
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
        if ($this.data.newArticle === true) {
          return true;
        }
        ev.preventDefault();
        $this.cancel_UI_toggle();
        $this.editUrlChange(false);
        $this.autoSave.stopSaving();
        $(".article-edit-form")[0].reset();
        $('.breadcrumb').removeClass('breadcrumb-edit');
        $this.highlightCode();

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
      $("#article-prop-" + this.data.articleId + "-cancel").bind("click", function () {
        $("#article-prop-" + $this.data.articleId + ' form').resetForm();
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
        } else {
          var error_elem = $('#article-form .error:input:first');
          if (error_elem.is('.select2')) {
          	error_elem.select2('focus');
          } else {
          	error_elem.focus();
          }
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

    outdateOrUpdate: function () {
      var $this = this;
      $('body').on('click.articles', '#outdate, #uptodate', function () {
        var el = $(this);
        $(this).button('loading');
        $.ajax({
          url: el.data('url'),
          type: 'PUT',
          dataType: 'json',
          data: {
            item_id: el.data('itemId'),
            language_id: el.data('languageId')
          },
          success: function () {
            el.button('complete');
            setTimeout($this.postOutdateUpdate(el), 2000);
          }
        });
      });
    },

    postOutdateUpdate: function (el) {
      el.parent().addClass('hide');
      $('.uptodate-section').removeClass('hide');
      if(el.attr('id') === 'outdate') {
        $('.lang-tab:not(".selected") .language_symbol.active').removeClass('active').addClass('outdated');
      } else {
        $('.lang-tab.selected .language_symbol').removeClass('outdated').addClass('active');
      }
    },

    formatTranslationDropdown: function () {
      $('#version_selection').select2({
        formatResult: this.format,
        formatSelection: this.format,
        escapeMarkup: function(m) { return m; },
        dropdownAutoWidth: 'true',
        containerCssClass: 'add-translation-link',
        dropdownCssClass: 'add-translation-dropdown'
      });
    },

    format: function (state) {
      var originalOption = state.element, outdated;
      return "<span class='language_symbol " + $(originalOption).data('state') + "'>" + "<span class='language_name'>" + $(originalOption).data('code') + "</span></span>" + "<span class='language_label'>" + state.text + "</span>";
    },

    showVersionDropdown: function () {
      $('body').on('click.articles', '.version_select_container', function () {
        $('#version_selection').select2('open');
      });
    },

    versionSelection: function () {
      $('body').on('change.articles', '#version_selection', function () {
        var el = $('#version_selection option[value=' + this.value + ']');
        var lang = this.value;
        $('#version_selection').select2('val', '');
        if (el.data('state') === "") {
          window.pjaxify("/solution/articles/new/" + $(this).data('articleId') + "/" + lang);
        } else {
          window.pjaxify("/solution/articles/" + $(this).data('articleId') + "/" + lang);
        }
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
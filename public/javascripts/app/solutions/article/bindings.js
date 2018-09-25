/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax, escapeHtml */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    copyArticleLinkEvent: null,

    showPageBindings: function () {
      var $this = this;
      this.articleHistoryEllipsisExpand();
      this.cumulativeStatsToggle();

      this.bindForCancelBtn();
      this.bindForEditBtn();
      this.bindForShowMaster();
      this.bindForCopyBtn();

      this.modalBindings();
      this.outdateOrUpdate();
    },

    modalBindings: function () {
      var $this = this;
      $('body').on('modal_loaded.articles', function () {
        $this.articleTags = $('#tags_name').val();
        $this.articleTags = $this.articleTags !== "" ? $this.articleTags.split(",") : "";
        $this.articleProperties();
        $this.checkTranslations();

        // Check rendered SEO meta length on modal load
        jQuery(this).find('#article-form [rel=charcounter]').each(function(pos,item){
          $this.validateSeoLength(item)
        });
        // Bind keyup SEO meta checks
        $this.seoCharCounter();
      });
    },

    bindForEditBtn: function () {
      var $this = this;
      $('body').on('click.articles', '.article-edit-btn', function () {
        $this.startEditing();
        $('.breadcrumb').addClass('breadcrumb-edit');
      });
    },

    bindForCopyBtn: function () {
      var $copyElement = $('.article-link-copy-btn');
      this.copyArticleLinkEvent = new Clipboard('.article-link-copy-btn', {
        text: function (target) {
          return target.querySelector('#article-link-copy-btn').href;
        }
      });

      this.copyArticleLinkEvent.on('success', function () {
        var $contentEle = $copyElement.children('.content');
        $copyElement.addClass('btn--copied');
        $contentEle.text($copyElement.data('text-copied'));
      });
    },

    dummyActionButtonTriggers: function () {
      $('body').on('click.articles', '#save-btn, #publish-btn', function () {
        var targetBtn = $(this).data().targetBtn;
        $(targetBtn).trigger('click');
      });
    },

    articleHistoryEllipsisExpand: function () {
      $('body').on('click.articles', '.article-history .ellipsis', function () {
        $('.created-history').toggleClass('hide');
        $('.article-history .ellipsis').toggleClass('hide');
      });
    },

    cumulativeStatsToggle: function () {
      $('body').on('click.articles', '.analytics .show-cumulative-stats', function () {
        $('.analytics .cumulative-stats').toggleClass('hide');
        $('.analytics .show-cumulative-stats').toggleClass('drop-right selected');
      });
    },

    attachmentsDelEvents: function () {
      $(document).on('attachment_deleted', function (ev, data) {
        $(".article-view #helpdesk_" + data.attachment_type + "_" + data.attachment_id).remove();
        $(".article-edit #helpdesk_" + data.attachment_type + "_" + data.attachment_id).fadeOut(500, function () { $(this).remove(); });
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

    seoCharCounter: function () {
      var $this = this;

      // Validate on keyup
      $('body').on('keyup.articles', '#article-form [rel=charcounter]', function (ev) {
        $this.validateSeoLength(ev.target);
      });
    },

    validateSeoLength: function (element) {
      var originalMsg = $(element).data('org-msg'),
          limitMsg = $(element).data('limit-msg'),
          recommended = $(element).data('limit'),
          contentLength = $(element).val().length;

      if(contentLength > recommended) {
        $(element).next('div.muted').html(limitMsg);
      } else {
        $(element).next('div.muted').html(originalMsg);
      }
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

        if ($this.autoSave.totalCount > 0) {
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

    checkTranslations: function () {
      $("body").on('change.articles', '#solution_article_meta_solution_folder_meta_id', function () {
        $('.check-translations').toggleClass('hide', $(this).data('originalValue') === parseInt($(this).val(), 10));
      });
    },

    formValidate: function () {
      var $this = this, error_elem;
      $('body').on('submit.articles', '.article-edit #article-form', function (ev) {
        var validation = $('#article-form').valid();
        if (validation) {
          if (!$.isEmptyObject($this.autoSave)) {
            $this.autoSave.stopSaving();
          }
          $(window).off('beforeunload.articles');
        } else {
          error_elem = $('#article-form .error:input:first');
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
      $('body').on('click.articles', '.outdate-uptodate', function (e) {
        var el = $(this),
					flag = $(e.target).is(":button") || $(e.target).parent().is(":button");
        if (flag) {
          $(e.target).parent().button('loading');
        }
        $.ajax({
          url: el.data('url'),
          type: 'PUT',
          dataType: 'html',
          data: {
            item_id: el.data('itemId'),
            language_id: el.data('languageId')
          },
          success: function (result) {
            flag ? el.button('complete') : el.remove();
            setTimeout(function () {
              (el.data('actionType') === 'mark-outdated') ? $this.postOutdate(result) : $this.postUptodate();
            }, 2000);
          }
        });
      });
    },

    postOutdate: function (result) {
      $('.outdate-section').fadeOut();
      $('.language-tabs').html(result);
      $('.lang-tab').first().addClass('selected');
      this.formatTranslationDropdown();
    },

    postUptodate: function () {
      $('.update-section').hide();
      $('.lang-tab.selected .language_symbol').removeClass('outdated');
    },

    triggerTranslationsModal: function () {
      $.freshdialog({
        title: this.STRINGS.addTranslationsTitle,
        targetId: "#add-translations",
        width: "500px",
        backdrop: 'static',
        keyboard: "false",
        showClose: "false"
      });
    },

    formatTranslationDropdown: function () {
      $('#version_selection').select2(
        $.extend({}, App.Solutions.translationDropdownOpts, {
          containerCssClass: 'add-translation-link',
          formatResult: App.Solutions.formatLangOptions
        })
      );
    },

    showVersionDropdown: function () {
      $('body').on('click.articles', '.version_select_container', function () {
        $('#version_selection').select2('open');
      });
    },

    versionSelection: function () {
      $('body').on('change.articles', '#version_selection', function () {
        var el = $('#version_selection option[value=' + this.value + ']'),
					lang = this.value,
          path = "/solution/articles/" + $(this).data('articleId') + "/" + lang;
        $('#version_selection').select2('val', '');
        if (el.data('state').indexOf('unavailable') !== -1) {
          path += "#edit";
        }
        window.pjaxify(path);
      });
    },

    bindForShowMaster: function () {

      $('body').on('click.articles', '#draft-tab', function () {
        $('#master-draft').trigger('afterShow');
      });

      $('body').on('click.articles', '#show_master_article', function (ev) {
        ev.preventDefault();
        $('#show_master_article').fdpopover('show').toggleClass('disabled');
        $('#master-article-tab a:last').tab('show');
        $('.fd-popover .master-article-tab-content div:last').trigger('afterShow');
      });

      $('body').on('click.articles', '.fd-popover-close', function () {
        $('#show_master_article').toggleClass('disabled');
      });

      $('#show_master_article').fdpopover({
        trigger: "manual",
        html: true,
        content: function () {
          return $('#master_article').html();
        },
        offset: 20
      });


    },

    toggleShowMaster: function () {
      $('#show_master_article').toggleClass('hide');
    }
  });
}(window.jQuery));

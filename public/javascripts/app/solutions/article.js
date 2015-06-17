/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {
    
    data: {},

    onVisit: function (data) {
      
      if (App.namespace === "solution/articles/new") {
        this.eventsForNewPage();
      }
			
      this.resetData();
      this.setDataFromPage();
      this.bindHandlers();
      this.handleEdit();
      highlight_code();
      App.Solutions.SearchConfig.onVisit();
    },
    
    onLeave: function (data) {
      $('body').off('.articles');
      App.Solutions.SearchConfig.onLeave();
    },

    handleEdit: function () {
      if (window.location.hash === "#edit") {
        $(".article-edit-btn").trigger('click');
      }
    },
    
    resetData: function () {
      this.data.title = null;
      this.data.description = null;
    },

    editUrlChange: function (editingFlag) {
      window.location.hash = (editingFlag ? "#edit" : "");
    },
    
    setDataFromPage: function () {
      this.data = $('#article-form').data() || {};
      this.data.title = $('#current-article-title').text();
      this.data.description = $('#current-article-description').html();
    },

    bindHandlers: function () {
      var $this = this;
      this.bindForMasterVersion();
      $('body').on('click.articles', '.article-edit-btn', function () {
        $this.startEditing();
      });
      $('body').on('click.articles', '.article-history .ellipsis', function () {
        $('.created-history').toggleClass('hide');
        $('.article-history .ellipsis').toggleClass('hide');
      });
    },
		
		toggleViews: function () {
			$('.article-edit, .article-view').toggleClass('hide');
		},
    
    startEditing: function () {
      $('.sub-content.article-edit').html($('.sub-content.article-view').html());
      this.setFormValues();
      this.toggleViews();

      //initilaizing autosave
      if (window.articleDraftAutosave) {
        window.articleDraftAutosave.startSaving();
      } else {
        window.articleDraftAutosave = this.autosaveInitialize();
      }
      
      if ($("#article-form").data().defaultFolder) {
        this.defaultFolderValidate();
      }

      this.editUrlChange(true);
      //Disbale the input for cancel draft changes by default
      $('#cancel_draft_changes_input').prop('disabled', true);
    },
    
    setFormValues: function () {
      $('#solution_article_title').val(this.data.title);
      $('#solution_article_description').setCode(this.data.description);
    },
    
    bindForMasterVersion: function () {
      var $this = this;
      $(window).on('resize.articles', function () {
        $('.masterversion').height(parseInt($(document).height(), 10));
      }).trigger('resize.article');

      $('body').on('click.articles', '.masterversion-link', function () {
        $this.animateMasterver(35);
        $(this).addClass('disable');
      });

      $('body').on('click.articles', '.close-link', function () {
        $this.animateMasterver(470);
        $('.masterversion-link').removeClass('disable');
      });
    },

    animateMasterver: function (distance) {
      if ($('html').attr('dir') === 'rtl') {
        $('.master-content').animate({
          right: distance
        });
      } else {
        $('.master-content').animate({
          left: distance
        });
      }
    },
    
    eventsForNewPage: function () {
      this.bindPropertiesToggle();
      this.formatSeoMeta();
      this.select2Tags();
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

    bindForCancel: function () {
      var $this = this;
      $("body").on('click.article', "#edit-cancel-button", function (ev) {
        ev.preventDefault();
				$this.articleDraftAutosave.stopSaving();
        $(".article-edit-form")[0].reset();
        $this.setFormValues();
				$this.resetDraftRequest();
        $this.articleDraftAutosave.contentChanged = false;
				$this.cancel_UI_toggle();
        $this.editUrlChange(false);
      });
    },
    
    resetDraftRequest: function () {
      $('#cancel_draft_changes_input').prop('disabled', false);
      //request for submitting serialized form if a draft already existed
      var form_submit = {
        type: 'POST',
        data: $('.article-edit-form').serialize(),
        dataType: "script"
      },
      //request for discarding draft if a draft didn't exist initially
				draft_discard = {
					type: 'DELETE',
					url: $('.article-edit-form').data().draftDiscardUrl,
					dataType: "json"
				},
				handlers = {
					success: function () {
						console.log('Cancel success');
          //TODO What all to do in cancel request
					},
					error: function () {
						console.log('Cancel error');
					}
				},
				request = $.extend({}, handlers, ($("#last-updated-at").length === 0 ? draft_discard : form_submit));
      //Only if a single autosave is success should we reverse the changes done
      if (this.articleDraftAutosave.successCount > 0) {
        $.ajax(request);
      }
    },

    cancel_UI_toggle: function () {
      this.toggleViews();
      $('.article-view-edit:hidden').show();
      $(".autosave-notif:visible").hide();
    },

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
        responseCallback: $.proxy(this.autosaveDomManipulate, this)
      };

      this.articleDraftAutosave  = $.autoSaveContent(draft_options);
      this.bindForCancel();
      // Move these somewhere else
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
            html("Reload").attr('class', 'btn btn-small reload-btn');
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
          $.each(['#edit-cancel-button', '#save-as-draft-btn', '.btn-primary'], function (index, el) {
            $(el).prop('disabled', !$flag);
          });
          $('.confirm-delete').attr('disabled', !$flag);
        },
        manipulate: function (response, success) {
          var content = "";
          response = response || { msg: "Something went wrong!"};
          if (response.msg) {
            content = this.htmlToStr(this.message(response.msg, success));
            content += this.htmlToStr(success ? this.liveTimeStamp() : this.reloadButton());

            // this.msgElement.html(content).show();
            this.msgElement.html(content).filter(':hidden').show();
            $('.article-view-edit:visible').hide();
            this.themeChange(!success);
            this.lastUpdatedAt(response);
            this.toggleButtons(success);
          }
        }

      };

      if (typeof (response) === 'object' && response.success) {
        changeDom.manipulate(response, true);
      } else {
        this.articleDraftAutosave.lastSaveStatus = false;
        changeDom.manipulate(response, false);
      }
    },

    articleProperties: function () {
      var $this = this;
      setTimeout(function () {
        $this.formatSeoMeta();
        $this.select2Tags();
        $("#article-prop-cancel").bind("click", function () {
          $('#article-prop-content #article-form').resetForm();
          $('#article-prop-content #article-form .select2').trigger('change');
        });
      }, 50);
    },

    unsavedContent: function () {
      // Check if there is an error, in that case return false.
      if (!this.articleDraftAutosave.lastSaveStatus) {
        return false;
      }
      // return (this.articleDraftAutosave.contentChanged || ($(".hidden_upload input").length > 1));
      return ($(".hidden_upload input").length > 1);
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
    },

    defaultFolderValidate: function () {
      $('body').on('click.articles', '#article-publish-btn', function () {
        if ($("#article-form").data().defaultFolder) {
          if ($('#solution_article_folder_id').val() === "") {
            $('.select-folder').show();
            return false;
          }
        }
        return true;
      });
    }

  };
}(window.jQuery));
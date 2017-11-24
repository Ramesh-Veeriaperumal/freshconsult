/**
 * @Srihari Surabhi
 * Plugin for Q&A module
 * Events :
 * Below events are fired. Listen to those events and act on them if needed.
 * After entire question is framed => 'question-complete' with data => JSON Array
 *
 * Version : 1.0
 */

HelpdeskReports.Qna_util = (function($) {
  var SEARCHABLE_OPTIONS_LENGTH = 5;

  var constants = {
    api: '/',
    filter_widgets: {
      '1': 'autocomplete_es', // include endpoint in json
      '2': 'autocomplete' // include key of object in json
    },
    question_prefixs: QLANG[I18n.locale] || QLANG['en'],
    events_namespace: '.qna',
    debug_mode: 0, // 0 for off, 1 for on,
    question_colors: [
      'rgba(229,78,66,0.2)',
      'rgba(231,174,31,0.2)',
      'rgba(123,182,46,0.2)',
      'rgba(69,147,226,0.2)'
    ],
    keyCodes: {
      ENTER: 13,
      ESCAPE: 27,
      UPARROW: 38,
      DOWNARROW: 40,
      DELETE: 46,
      BACKSPACE: 8
    },
    get navigationalKeys() {
      if (!_.isObject(this._navigationalKeys)) {
        var navigationalKeys = {};
        _.each(constants.keyCodes, function(val, key) {
          var excludedKeys = ['DELETE', 'BACKSPACE'];

          if (excludedKeys.indexOf(key) === -1) {
            navigationalKeys[key] = val;
          }
        });

        // cache the value for future property lookups
        this._navigationalKeys = navigationalKeys;

        return navigationalKeys;
      } else {
        return this._navigationalKeys;
      }
    },
    // this accomodates the speech bubble as part
    // of the qna search container, the same values
    // have been used in css
    initialInputBoxLeftOffset: 40,
    // this accomodates the clear query as part of the qna
    // search container
    initialInputBoxRightOffset: 45,
    emptyQuestionPrefixesInPopOverMessage: 'No results found'
  };

  var _q = {
    current_level: 0,
    question_prefix_count: 0,
    in_progress: true,
    request_param: {},
    filtering: false,
    populateSearchBox: function(selected_item) {
      var bg_color = '#fff'; //constants.question_colors[this.question_prefix_count];
      var $alreadySelectedQuestionPrefix = $(
        '.qna-search-bar .selected-queries'
      );

      var mkup =
        '<div class="value-block" data-level="' +
        this.current_level +
        '">' +
        (selected_item.attr('data-prefix') || '') +
        selected_item.html() +
        (this.current_level == -1 ? '?' : '') +
        '</div>';
      $('.selected-queries').append(mkup);
      this.question_prefix_count += 1;

      var $input = $('#search-query');

      $input.val('');

      // if the selected question prefixes were highlighted to indicate that
      // it would be reset in its entirety upon another keypress of
      // delete/backspace, and then user starts typing to select a prefix,
      // we should unhighlighted the already selected prefixes
      if ($alreadySelectedQuestionPrefix.hasClass('highlighted')) {
        $alreadySelectedQuestionPrefix.removeClass('highlighted');
      }

      this.resizeSearchInput();
    },
    populateQuestionPrefixes: function(current_level, selected_breadcrumb) {
      var source = {},
        options = [];
      var $popover = $('.question-popover');
      var $input = $('#search-query');
      var _this = this;
      if (current_level == -1) {
        //End of question
        _this.in_progress = false;
        //reset the questions populated count
        _this.question_prefix_count = 0;
        //cloes the question dropdown
        $popover.animate({ opacity: 'hide' }, 'fast');

        //Collect the text in the question box;
        _this.request_param['text'] =
          $('#search-query').attr('data-text') + '?';
        _this.request_param['markup'] = $('.selected-queries').html();
        if (constants.debug_mode == 1) {
          //console.log('firing query',_this.request_param);
        }
        trigger_event(
          'question-complete' + constants.events_namespace,
          _this.request_param
        );
      } else {
        if (current_level == 0) {
          selected_breadcrumb = 'start';
          _this.request_param['markup'] = '';
          _this.request_param['text'] = '';
          $input.attr('data-text', '');
        }
        //Happens when user focuses the input box while the search is in progress
        if (selected_breadcrumb == undefined) {
          selected_breadcrumb = _this.last_used_breadcrumb;
        } else {
          _this.last_used_breadcrumb = selected_breadcrumb;
        }

        source =
          constants.question_prefixs[current_level][selected_breadcrumb] || {};
        if (!jQuery.isEmptyObject(source)) {
          options = source['options'];
        }

        //clean the dropdown
        $('.questions').html('');

        if (options.length != 0) {
          if (
            source.searchable == 'true' &&
            options.length > SEARCHABLE_OPTIONS_LENGTH
          ) {
            var li = _.template(
              '<li class="search-header clearfix"><input type="text" placeholder="<%=placeholder%>" rel="filter_content"  /></li>'
            );
            var $li = $(
              li({
                placeholder: source.placeholder
              })
            );
            $('.questions').append($li);
          }

          jQuery.each(options, function(i, el) {
            if (source.hasOwnProperty('filter')) {
              var $li = $(
                '<li>' +
                  el.label +
                  '<i class="ficon-arrow-right icon-next"></i></li>'
              );
              $li.attr({
                'data-action': 'filter',
                'data-value': el.value,
                'data-widget': el.widget_type,
                'data-url': el.url,
                'data-src': el.src,
                'data-options_key': el.options,
                'data-prev-breadcrumb': source.back_breadcrumb,
                'data-prev-breadcrumb-level': source.back_breadcrumb_in,
                'data-breadcrumb': el.breadcrumb,
                'data-search-breadcrumb-in': el.search_breadcrumb_in,
                'data-req-key': source.req_key,
                'data-prefix': el.prefix
              });
              if (el.feature_check != undefined) {
                if (HelpdeskReports.features[el.feature_check] == true) {
                  $('.questions').append($li);
                }
              } else {
                $('.questions').append($li);
              }
            } else {
              var $li = $('<li>' + el.label + '</li>');
              $li.attr({
                'data-action': 'selector',
                'data-value': el.value,
                'data-breadcrumb': el.breadcrumb,
                'data-search-breadcrumb-in': el.search_breadcrumb_in,
                'data-req-key': source.req_key
              });

              if (el.feature_check != undefined) {
                if (HelpdeskReports.features[el.feature_check] == true) {
                  $('.questions').append($li);
                }
              } else {
                $('.questions').append($li);
              }
            }
          });

          if (current_level != 0) {
            _this.moveQuestionsPopover();
          }
        }
      }
    },
    searchQuestions: function(searchKeyword, labelsToChooseFrom) {
      worker.postMessage(searchKeyword, labelsToChooseFrom);
      return new Promise(function(resolve, reject) {
        worker.onmessage(function(event) {
          resolve(event.message);
        });
      });
    },
    populateFilters: function(source) {
      var $el = jQuery(source);
      var widget = $el.attr('data-widget');
      var condition = $el.attr('data-value');
      var url = $el.attr('data-url');
      var self_breadcrumb = $el.attr('data-prev-breadcrumb');
      var self_breadcrumb_level = $el.attr('data-prev-breadcrumb-level');
      var next_breadcrumb = $el.attr('data-breadcrumb');
      var next_breadcrumb_found_in = $el.attr('data-search-breadcrumb-in');
      var req_key = $el.attr('data-req-key');
      var prefix = $el.attr('data-prefix');

      if (constants.filter_widgets[widget] == 'autocomplete_es') {
        var url = $el.attr('data-url');

        $('.questions').html('');

        var search_head_mkup = _.template(
          '<li class="search-header wide-width clearfix"><i class="back-nav ficon-left-arrow-thick" data-action="backnav" data-breadcrumb="<%= breadcrumb %>" data-search-breadcrumb-in="<%= search_in %>"> </i> <input type="text" id="<%=condition%>" data-url="<%=url%>" data-next-breadcrumb= "<%=next_breadcrumb%>" data-next-breadcrumb-in = "<%=next_breadcrumb_found_in %>" data-req-key="<%=req_key%>" data-prefix="<%=prefix%>" placeholder="Type 2 or more characters" rel="remote-search" class="filter_item" /></li>'
        );

        $('.questions').html(
          search_head_mkup({
            condition: condition,
            url: url,
            breadcrumb: self_breadcrumb,
            search_in: self_breadcrumb_level,
            next_breadcrumb: next_breadcrumb,
            next_breadcrumb_found_in: next_breadcrumb_found_in,
            req_key: req_key,
            prefix: prefix
          })
        );

        //Construct options
      } else if (constants.filter_widgets[widget] == 'autocomplete') {
        var src = $el.attr('data-src');
        var options = HelpdeskReports.locals[src];

        $('.questions').html('');

        var search_head_mkup = _.template(
          '<li class="search-header wide-width clearfix"><i class="back-nav ficon-left-arrow-thick" data-action="backnav" data-breadcrumb="<%= breadcrumb %>" data-search-breadcrumb-in="<%= search_in %>"> </i> <input type="text" rel="filter_content" class="filter_item" /></li>'
        );
        $('.questions').html(
          search_head_mkup({
            breadcrumb: self_breadcrumb,
            search_in: self_breadcrumb_level
          })
        );

        jQuery.each(options, function(index, item) {
          var $li = $('<li class="wide-width">' + item[1] + '</li>');

          $li.attr({
            'data-action': 'selector',
            'data-value': item[0],
            'data-condition': condition,
            'data-breadcrumb': next_breadcrumb,
            'data-search-breadcrumb-in': next_breadcrumb_found_in,
            'data-req-key': req_key,
            'data-condition': condition,
            'data-prefix': prefix
          });
          $('.questions').append($li);
        });

        if (options.length == 0) {
          var $emptyli = $('<li class="wide-width">No Data</li>');
          $('.questions').append($emptyli);
        }
      }

      // focus the input box in search header
      $('.search-header > input[type=text]').focus();
    },
    moveQuestionsPopover: function() {
      var $selected_queries = $('.selected-queries');
      var $popover = $('.question-popover');

      var width = $selected_queries.width();
      var left_pos = $selected_queries.position().left;
      var current_position = $popover.position().left;

      var translate_by = width + left_pos - current_position;
      $popover.animate(
        {
          left: '+=' + translate_by
        },
        300,
        'swing'
      );
    },
    reset: function() {
      var _this = this;
      var $popover = $('.question-popover');
      var $input = $('#search-query');

      _this.in_progress = true;
      _this.current_level = 0;
      _this.question_prefix_count = 0;
      _this.request_param = {};

      $popover.animate({ opacity: 'hide' }, { duration: 0 });
      $('.selected-queries').empty();
      $popover.css({
        left: '30px'
      });

      var $container = $('.search-field-holder');
      var containerWidth = $container.width();
      var inputWidth =
        containerWidth -
        constants.initialInputBoxLeftOffset -
        constants.initialInputBoxRightOffset;

      $container.removeAttr('readonly');

      if ($container.hasClass('active')) {
        $input.css({
          width: inputWidth,
          left: constants.initialInputBoxLeftOffset
        });
      }
    },
    filterList: function() {
      var filter_text = $('[rel=filter_content]').val();

      if (!this.filtering) {
        this.filtering = true;
        if (filter_text != undefined && filter_text.length > 0) {
          filter_text = filter_text.toLowerCase();
          jQuery.each($('.questions li').not('.search-header'), function(
            i,
            el
          ) {
            var innerHtml = $(el)
              .html()
              .trim()
              .toLowerCase();
            if (innerHtml.indexOf(filter_text) > -1) {
              $(el).show();
            } else {
              $(el).hide();
            }
          });
          this.filtering = false;

          // highlight the first choice automatically
          $('.questions li:not(".search-header")').removeClass('active');

          $('.questions li:not(".search-header")')
            .filter(':not(:hidden)')
            .first()
            .addClass('active');
        } else {
          // $(".questions li").not('.search-header').velocity('slideDown');
          this.filtering = false;
        }
      }
    },
    build_params: function($li) {
      var value = $li.attr('data-value');
      var key = $li.attr('data-req-key');

      if (key == 'filter_value') {
        this.request_param['filter_key'] = $li.attr('data-condition');
      }

      //Search input
      var $input = $('#search-query');
      var text = $input.attr('data-text');
      if (text != undefined) {
        $input.attr(
          'data-text',
          text + ' ' + ($li.attr('data-prefix') || '') + $li.html()
        );
      } else {
        $input.attr('data-text', ($li.attr('data-prefix') || '') + $li.html());
      }
      this.request_param[key] = value;
    },
    clear_params: function() {
      this.request_param = {};
      $('#search-query').removeAttr('data-text');
    },
    initMatchSorterWorker: function() {
      this.matchSorter = new Worker(
        'assets/cdn/reports-match-sorter.worker.js'
      );
    },
    filterQuestionPrefixesWithMatchSorterWorker: function(
      filterKeyword,
      labelsToChooseFrom
    ) {
      if (!this.matchSorter) {
        return;
      }

      var _this = this;

      return new Promise(function(resolve, reject) {
        _this.matchSorter.postMessage({
          items: labelsToChooseFrom,
          keyword: filterKeyword
        });

        _this.matchSorter.onmessage = function(event) {
          resolve(event.data);
        };

        setTimeout(function() {
          reject('timeout');
        }, 100);
      });
    },
    filterQuestionPrefixesFromPopup: function(labelsToFilterWith) {
      $questionsPopoverContainer = $('.question-popover .questions');
      $questionsInPopover = $('.question-popover .questions li');

      var orderedPrefixesList = [];
      var lastMatchedItemIndex = -1;

      this.resetQuestionsPopover();

      $questionsInPopover.each(function(index, el) {
        var $el = $(el);
        var labelForQuestionPrefix = $el.text();
        var matchedItemIndex = labelsToFilterWith.indexOf(
          labelForQuestionPrefix
        );

        if (matchedItemIndex === -1) {
          $el.hide();
        } else {
          // lets preserve the order as returned by match-sorter
          if (matchedItemIndex < lastMatchedItemIndex) {
            orderedPrefixesList.splice(0, 0, $el);
          } else {
            orderedPrefixesList.push($el);
          }
          lastMatchedItemIndex = matchedItemIndex;
        }
      });

      if (orderedPrefixesList.length === 0) {
        if ($('.question-prefixes-empty-message').length === 0) {
          $questionsPopoverContainer.append(
            $(
              '<span class="question-prefixes-empty-message">' +
                constants.emptyQuestionPrefixesInPopOverMessage +
                '</span>'
            )
          );
        }
      } else {
        $('.question-prefixes-empty-message').remove();
      }

      // lets match the sorting order provided by match-sorter
      // arrange the items within the popover with the given sort order
      if (orderedPrefixesList.length > 1) {
        orderedPrefixesList.reverse();
        _.each(orderedPrefixesList, function($el) {
          $el.insertBefore('.question-popover .questions li:eq(0)');
        });
      }

      // highlight the first item in the newly *filtered* popover list
      if ($('.question-popover .questions li:not(:hidden)').length > 0) {
        $('.question-popover .questions li').removeClass('active');
        $('.question-popover .questions li:not(:hidden)')
          .first()
          .addClass('active');
      }
    },
    resizeSearchInput: function() {
      // the search input box and the selected queries element(the parts of
      // question prefixes which the user has already selected) are placed
      // side by side, when a user selects a questions prefix the selected
      // queries should increase in width and the input box should decrease
      // together the input box and the selected queries comprises the width
      // of the entire qna search bar
      var $selectedQuery = $('.selected-queries');
      var $searchInput = $('#search-query');
      var $container = $('.search-field-holder');
      var containerWidth = $container.width();
      var reduceInputByWidth = $selectedQuery.width();
      var reducedSearchInputWidth =
        containerWidth -
        reduceInputByWidth -
        constants.initialInputBoxLeftOffset -
        constants.initialInputBoxRightOffset;

      $searchInput.css({
        left: reduceInputByWidth + constants.initialInputBoxLeftOffset,
        width: reducedSearchInputWidth
      });
    },
    resetQuestionsPopover: function() {
      $questionsInPopover = $('.question-popover .questions li');
      $noQuestionPrefixesMessage = $('.question-prefixes-empty-message');

      // show all the items in the popover
      $questionsInPopover.show();
      $questionsInPopover
        .removeClass('active')
        .first()
        .addClass('active');
      $noQuestionPrefixesMessage.remove();
    },
    handleKeyupOnSearchBox: function(e) {
      var keyCode = e.keyCode;
      if (_.values(constants.navigationalKeys).indexOf(keyCode) !== -1) {
        // the navigation keys rotate the highlighted item in the UI
        // as this operation does not involve filtering of the items
        // it is expected to be faster than the filtering
        _.debounce(this.handleKeyboardNavigationOnQuestionPrefixes(e), 100);
      } else {
        _.debounce(this.handleTextEntryToFilterQuestionPrefixes(e), 500);
      }
    },
    handleKeyboardNavigationOnQuestionPrefixes: function(e) {
      var keyCode = e.keyCode;
      var $questionsInPopover = $(
        '.question-popover .questions li:not(.search-header)'
      );

      var _getAdjacentItemToHighlightedItem = function($activeItem, direction) {
        // items gets hidden when they don't match user's search keyword
        var $visibleItemsInPopover = $questionsInPopover.filter(
          ':not(:hidden)'
        );

        var highlightedItemIndexInVisibleItems = $visibleQuestionsInPopover.index(
          $activeItem
        );

        // there is highlighted item in the list
        if (highlightedItemIndexInVisibleItems === -1) {
          return undefined;
        }

        if (direction === 'prev') {
          return $visibleItemsInPopover[highlightedItemIndexInVisibleItems - 1];
        } else if (direction === 'next') {
          return $visibleItemsInPopover[highlightedItemIndexInVisibleItems + 1];
        }
      };

      if (
        keyCode === constants.keyCodes.UPARROW ||
        keyCode === constants.keyCodes.DOWNARROW
      ) {
        // items in the question popover gets hiddens
        // as user types in letters, our purpose is to just select
        // the next item from the *visible* items in the popover
        var $visibleQuestionsInPopover = $questionsInPopover.filter(
          ':not(:hidden)'
        );

        var $activeItem = $questionsInPopover.filter('.active:not(:hidden)');

        $activeItem.removeClass('active');

        if ($activeItem.length > 0) {
          if (keyCode === constants.keyCodes.UPARROW) {
            var prevItem = _getAdjacentItemToHighlightedItem(
              $activeItem,
              'prev'
            );

            if (_.isUndefined(prevItem)) {
              $visibleQuestionsInPopover.last().addClass('active');
            } else {
              $(prevItem).addClass('active');
            }
          } else if (keyCode === constants.keyCodes.DOWNARROW) {
            var nextItem = _getAdjacentItemToHighlightedItem(
              $activeItem,
              'next'
            );

            if (_.isUndefined(nextItem)) {
              $visibleQuestionsInPopover.first().addClass('active');
            } else {
              $(nextItem).addClass('active');
            }
          }
        } else {
          $visibleQuestionsInPopover.first().addClass('active');
        }
      } else if (keyCode === constants.keyCodes.ENTER) {
        var $activeItem = $questionsInPopover.filter('.active:not(:hidden)');

        // emulate click event on the highlighted item
        $activeItem.click();
      }
    },
    handleTextEntryToFilterQuestionPrefixes: function(e) {
      // no need to handle the event if it was fired on
      // on the input item in search header of the filter list
      // this filter list is a secondary input which pops up
      // upon selecting agents, groups
      // its handled in another handler
      if ($(e.target).hasClass('filter_item')) {
        return;
      }

      var $input = $('#search-query');
      var inputText = $input.val();
      var $alreadySelectedQuestionPrefix = $(
        '.qna-search-bar .selected-queries'
      );

      // when question prefixes is filtered against an empty string
      // we need to show all of them, this happens when a user deletes
      // to an empty search box
      if (inputText === '') {
        // show all question prefixes and highlight the first item
        this.resetQuestionsPopover();

        // we want to reset the entire search box after the user hits
        // DELETE **twice** on an input box, its very intuitive to clear the
        // search box of all letters and type the query again
        // hence we do not reset the search when we find the input
        // text to be blank for the first time, but we reset it after the user
        // hits DELETE or BACKSPACE the subsequent time
        if (!_.isFunction(this._clearQueryAfterInvokedTwice)) {
          var clearQueryFn = function() {
            $('[data-action="clear-query"]').click();
          };
          this._clearQueryAfterInvokedTwice = invokeAfterNth(clearQueryFn, 2);
        }

        if (
          e.keyCode === constants.keyCodes.DELETE ||
          e.keyCode === constants.keyCodes.BACKSPACE
        ) {
          // highlight all question prefixes already selected to indicate
          // the next delete/backspace will reset to an empty search instead
          // of only deleteing the previous prefix(intuitively people will expect that)
          $alreadySelectedQuestionPrefix.addClass('highlighted');
          this._clearQueryAfterInvokedTwice();
        }

        return;
      }

      this._clearQueryAfterInvokedTwice = undefined;

      if ($alreadySelectedQuestionPrefix.hasClass('highlighted')) {
        $alreadySelectedQuestionPrefix.removeClass('highlighted');
      }

      var questionPrefixes = constants.question_prefixs;
      var currentLevel = this.current_level;

      var currentQuestionPrefeixesInPopup =
        questionPrefixes[currentLevel][this.last_used_breadcrumb].options;

      var labelsForQuestionPrefixesInPopup = currentQuestionPrefeixesInPopup.map(
        function(item) {
          return item.label || '';
        }
      );

      this.filterQuestionPrefixesWithMatchSorterWorker(
        inputText,
        labelsForQuestionPrefixesInPopup
      ).then(this.filterQuestionPrefixesFromPopup.bind(this));
    },
    bindEvents: function() {
      var _this = this;
      // used to track two consecutive backspace/delete on
      // input boxes. the qna search bar only resets when a user
      // hits DELETE twice on an empty search box
      var toggleBackspaceForSecondaryInputFilter = 0;
      var toggleBackspaceForSecondaryRemoteSearchFilter = 0;

      var $doc = $(document),
        $input = $('#search-query'),
        $results = $('.search-results'),
        $left_section = $('.left-section'),
        $base = $('.base-content'),
        $insights = $('.insights'),
        $popover = $('.question-popover'),
        $selcted_queries = $('.selected-queries'),
        $answer_section = $('.answer-section');

      //flush existing events
      $doc.off(constants.events_namespace);

      $doc.on(
        'focus' + constants.events_namespace,
        '#search-query',
        function() {
          if (_this.current_level === 0) {
            _this.reset();

            trigger_event('question-focus' + constants.events_namespace);

            $('.search-field-holder').addClass('active');
            //Remove placeholder
            $('.search-field-holder input').prop('placeholder', '');
            //Show the clear icon
            $('.clear-query,.close-search').removeClass('hide');

            if (_this.in_progress) {
              _this.populateQuestionPrefixes(_this.current_level);
              $popover.animate({ opacity: 'show' }, 'slow');
            }
          }
        }
      );

      $doc.on(
        'keyup' + constants.events_namespace,
        '#search-query, .search-header>input',
        function(e) {
          _this.handleKeyupOnSearchBox(e);
        }
      );

      // highlight the question prefix options as one hovers over them
      // the addition of a class instead of a CSS rule for hover state makes it
      // possible to enable the highlighting through keyboard navigation as well
      $doc.on(
        'mouseover' + constants.events_namespace,
        '.question-popover li:not(search-header)',
        function(e) {
          $('.question-popover li').removeClass('active');

          $(e.target).addClass('active');
        }
      );

      $doc.on(
        'click' + constants.events_namespace,
        '[data-action="close-search"]',
        function() {
          trigger_event('question-close' + constants.events_namespace);

          $popover.hide();
          $('.search-field-holder').removeClass('active');
          //Remove placeholder
          $('.search-field-holder input')
            .val('')
            .prop('placeholder', 'Ask me a question about your helpdesk');
          //Show the clear icon
          $('.clear-query').addClass('hide');
          $(this).addClass('hide');
          _this.clear_params();
          _this.reset();
        }
      );

      $doc.on(
        'click' + constants.events_namespace,
        '[data-action=clear-query]',
        function() {
          var $searchInput = $('#search-query');
          _this.reset();
          _this.clear_params();
          trigger_event('question-cleared' + constants.events_namespace);

          setTimeout(function() {
            $searchInput.focus();
            _this.resetQuestionsPopover();
          }, 100);
        }
      );

      //breadcrumb query[selection]
      $doc.on(
        'click' + constants.events_namespace,
        '[data-action=selector]',
        _.debounce(function(ev) {
          _this.current_level =
            $(this).attr('data-search-breadcrumb-in') || '-1';
          _this.populateSearchBox($(this));
          _this.build_params($(this));
          _this.populateQuestionPrefixes(
            _this.current_level,
            $(this).attr('data-breadcrumb')
          );

          // in case of prefixes which invokes a filter list
          // with search header input, we focus this particular
          // input on opening this filter list, so when a user
          // selects an item from the filter list we need to focus back
          // to the primary search field
          if ($('#search-query:focus').length === 0) {
            $('#search-query').focus();
          }
        }, 250)
      );

      //back nav query
      $doc.on(
        'click' + constants.events_namespace,
        '[data-action=backnav]',
        function(ev) {
          _this.current_level =
            $(this).attr('data-search-breadcrumb-in') || '-1';
          _this.populateQuestionPrefixes(
            _this.current_level,
            $(this).attr('data-breadcrumb')
          );

          // put focus back on the main search bar
          $('#search-query').focus();
        }
      );

      //Show filters
      $doc.on(
        'click' + constants.events_namespace,
        '.questions li[data-action=filter]',
        function(ev) {
          _this.populateFilters(this);
        }
      );

      //Remote Filter fetch
      $doc.on(
        'keyup' + constants.events_namespace,
        '[rel="remote-search"]',
        function(ev) {
          var $el = $(this);

          var clearQueryFn = function() {
            if (toggleBackspaceForSecondaryRemoteSearchFilter === 1) {
              $('[data-action=backnav]').click();
              toggleBackspaceForSecondaryRemoteSearchFilter = 0;
            } else {
              toggleBackspaceForSecondaryRemoteSearchFilter += 1;
            }
          };

          if (
            ev.keyCode === constants.keyCodes.BACKSPACE ||
            ev.keyCode === constants.keyCodes.DELETE
          ) {
            // when a user presses a backspace or a delete on an empty filter
            // list, lets navigate back to the previous menu
            if ($(ev.target).val() === '') {
              clearQueryFn();
              return;
            }
          } else if (
            !(
              ev.keyCode === constants.keyCodes.DOWNARROW ||
              ev.keyCode === constants.keyCodes.ENTER
            )
          ) {
            var url = $el.attr('data-url');
            var condition = $el.attr('id');
            var next_breadcrumb = $el.attr('data-next-breadcrumb');
            var next_breadcrumb_found_in = $el.attr('data-next-breadcrumb-in');
            var req_key = $el.attr('data-req-key');
            var condition = $el.attr('id');
            var prefix = $el.attr('data-prefix');
            _this.remoteSearch(
              condition,
              url,
              next_breadcrumb,
              next_breadcrumb_found_in,
              req_key,
              condition,
              prefix
            );
          }
        }
      );

      //options filter
      $doc.on(
        'keyup' + constants.events_namespace,
        '[rel=filter_content]',
        function(e) {
          var clearQueryFn = function() {
            if (toggleBackspaceForSecondaryInputFilter === 1) {
              $('[data-action=backnav]').click();
              toggleBackspaceForSecondaryInputFilter = 0;
            } else {
              toggleBackspaceForSecondaryInputFilter += 1;
            }
          };

          // when a user presses a backspace or a delete on an empty filter
          // list, lets navigate back to the previous menu
          if (
            e.keyCode === constants.keyCodes.BACKSPACE ||
            e.keyCode === constants.keyCodes.DELETE
          ) {
            if ($(e.target).val() === '') {
              clearQueryFn();
              return;
            }
          }

          if (_.values(constants.navigationalKeys).indexOf(e.keyCode) === -1) {
            _this.filterList();
          }

          return false;
        }
      );

      //same behavior as close action
      $doc.keyup(function(e) {
        if (e.keyCode == 27) {
          // escape key maps to keycode `27`
          trigger_event('question-close' + constants.events_namespace);

          _this.reset();

          $popover.animate({ opacity: 'hide' }, 'slow');
          $('.search-field-holder').removeClass('active');
          //Remove placeholder
          $('.search-field-holder input')
            .val('')
            .prop('placeholder', 'Ask me a question about your helpdesk')
            .blur();
          //Show the clear icon
          $('.clear-query').addClass('hide');
          $('.close-search').addClass('hide');

          $(this).addClass('hide');
          _this.clear_params();
        }

        return false;
      });
    },
    remoteSearch: function(
      condition,
      url,
      next_breadcrumb,
      next_breadcrumb_found_in,
      req_key,
      condition,
      prefix
    ) {
      var _this = this;
      $('.questions li')
        .not('.search-header')
        .remove();

      var text = $('[rel=remote-search]').val();
      if (text != undefined && text != '' && text.length >= 2) {
        var $spinner = $(
          '<li class="wide-width"><div class="sloading loading-small loading-block"></div></li>'
        );
        $('.questions').append($spinner);

        var config = {
          url: '/search/autocomplete/' + url,
          type: 'get',
          dataType: 'json',
          data: {
            q: text
          },
          success: function(data, params) {
            // arbitary safety mechanism to not overwrite question popover
            // list if the user has already moved passed the remote search phase
            if (!$('.questions li.search-header').length) {
              return;
            }

            $('.questions li')
              .not('.search-header')
              .remove();

            $.each(data.results, function(index, item) {
              var $li = $('<li class="wide-width">' + item.value + '</li>');

              $li.attr({
                'data-action': 'selector',
                'data-value': condition == 'agent' ? item.user_id : item.id,
                'data-breadcrumb': next_breadcrumb,
                'data-search-breadcrumb-in': next_breadcrumb_found_in,
                'data-req-key': req_key,
                'data-condition': condition,
                'data-prefix': prefix
              });
              $('.questions').append($li);
            });

            if (data.results.length == 0) {
              var $emptyli = $('<li class="wide-width">No results found</li>');
              $('.questions').append($emptyli);
            } else {
              // highlight the first choice automatically
              $('.questions li:not(".search-header")').removeClass('active');

              $('.questions li:not(".search-header")')
                .first()
                .addClass('active');
            }
          },
          cache: true
        };
        this.makeAjaxRequest(config);
      } else {
        $('.questions li')
          .not('.search-header')
          .remove();
      }
    },
    makeAjaxRequest: function(args) {
      args.url = args.url;
      args.type = args.type ? args.type : 'POST';
      args.dataType = args.dataType ? args.dataType : 'json';
      args.data = args.data;
      args.success = args.success ? args.success : function() {};
      args.error = args.error ? args.error : function() {};
      var _request = $.ajax(args);
    },
    showLoader: function(container) {
      $(container).append(
        '<div class="sloading loading-small loading-block"></div>'
      );
    },
    hideLoader: function(container) {
      $(container).remove();
    },
    init: function() {
      // if the current users's language is not English
      // hide the qna search bar
      try {
        if (DataStore.store.current_user.user.language !== 'en') {
          $('.report-head').hide();
          return;
        }
      } catch (e) {
        $('.report-head').hide();
        return;
      }

      this.bindEvents();
      this.reset();
      if (constants.debug_mode == 1) {
        Qna_test(I18n.locale);
      }

      // we are using web workers to filter the question prefixes
      // popover when a user starts typing, hence making the search
      // query box navigable via keyboard needs the browser to have web
      // workers support. Although most browsers have web workers support
      // we are maintaing a fallback which will not support keybaord naviagtion
      // while still retaining the mouse navigation as earlier
      if (window.Worker) {
        $('#search-query').removeAttr('readonly');
        // the usage of web workers was needed becuase we are using
        // a third-party party library to filter an array of strings against
        // a keyword and the library relies of native array and object methods
        // our client has modified native methods on Array and Object which
        // breaks the third-party application
        // Running the third-party library inside a web worker provides it with
        // an untouched environment
        this.initMatchSorterWorker();
      }
    }
  };

  return _q;
})(jQuery);

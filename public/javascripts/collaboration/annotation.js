/*
*   annotations.js
*
*/
(function(global, Annotation) {
    global.Annotation = Annotation();
})(this, function() {
    var ERROR_LOG_COLOR = "color: red; font-weight: 700;";
    var WRAPPER_ELEM_TAG = "span";
    var NOTE_CLASS_NAME = "details";
    var ORIGINAL_TICKET_ID = "ticket_original_request";
    var WRAPPER_ELEM_STYLE = "display: inline; background-color: rgba(255, 255, 0, 0.5); color: #5ca2c9;";
    var TIKCET_ID_HOLDER_SELECTOR = "#Pagearea .leftcontent";
    var TICKET_ID_ATTR = "data-ticket-id";
    var STATUS_FAIL = 0;
    var STATUS_SUCCESS = 1;

    function getCurrentTicketId() {
        return document.querySelector(TIKCET_ID_HOLDER_SELECTOR).getAttribute(TICKET_ID_ATTR);
    }

    function getParentForClass(el, cls) {
        while ((el = el.parentElement) && !el.classList.contains(cls));
        return el;
    }

    function getParentForId(el, id) {
        while ((el = el.parentElement) && !(el.getAttribute("id") === id));
        return el;
    }

    function log(){
        if(console && !!localStorage.debugCollab){
          var args = Array.prototype.slice.call(arguments);
          console.log.apply(console, args);
        }
    };

    /*
    *   Taken from:
    *   http://stackoverflow.com/questions/13949059/persisting-the-changes-of-range-objects-after-selection-in-html/13950376#13950376
    */
    function ssWindow(containerEl) {
        if(!containerEl) {
            console.log("containerEl not present");
            return {};
        }
        var range = window.getSelection().getRangeAt(0);
        var preSelectionRange = range.cloneRange();
        preSelectionRange.selectNodeContents(containerEl);
        preSelectionRange.setEnd(range.startContainer, range.startOffset);
        var start = preSelectionRange.toString().length;

        return {
            start: start,
            end: start + range.toString().length
        }
    };

    /*
    *   Taken from:
    *   http://stackoverflow.com/questions/13949059/persisting-the-changes-of-range-objects-after-selection-in-html/13950376#13950376
    */
    function rsWindow(containerEl, savedSel) {
        if(!containerEl) {
            console.log("containerEl not present");
            return {};
        }
        if(!saveSelection) {
            console.log("savedSel not present");
            return {};
        }
        var charIndex = 0, range = document.createRange();
        range.setStart(containerEl, 0);
        range.collapse(true);
        var nodeStack = [containerEl], node, foundStart = false, stop = false;
        
        while (!stop && (node = nodeStack.pop())) {
            if (node.nodeType == 3) {
                var nextCharIndex = charIndex + node.length;
                if (!foundStart && savedSel.start >= charIndex && savedSel.start <= nextCharIndex) {
                    range.setStart(node, savedSel.start - charIndex);
                    foundStart = true;
                }
                if (foundStart && savedSel.end >= charIndex && savedSel.end <= nextCharIndex) {
                    range.setEnd(node, savedSel.end - charIndex);
                    stop = true;
                }
                charIndex = nextCharIndex;
            } else {
                var i = node.childNodes.length;
                while (i--) {
                    nodeStack.push(node.childNodes[i]);
                }
            }
        }

        var sel = window.document.getSelection();
        if (!detectIE() || (sel.rangeCount > 0 && sel.getRangeAt(0).getClientRects().length > 0)) {
            sel.removeAllRanges();
        }
        sel.addRange(range);
    }

    /*
    *   Taken from:
    *   http://stackoverflow.com/questions/13949059/persisting-the-changes-of-range-objects-after-selection-in-html/13950376#13950376
    */
    function ssDoc(containerEl) {
        if(!containerEl) {
            console.log("containerEl not present");
            return {};
        }
        var selectedTextRange = document.selection.createRange();
        var preSelectionTextRange = document.body.createTextRange();
        preSelectionTextRange.moveToElementText(containerEl);
        preSelectionTextRange.setEndPoint("EndToStart", selectedTextRange);
        var start = preSelectionTextRange.text.length;

        return {
            start: start,
            end: start + selectedTextRange.text.length
        }
    };

    /*
    *   Taken from:
    *   http://stackoverflow.com/questions/13949059/persisting-the-changes-of-range-objects-after-selection-in-html/13950376#13950376
    */
    function rsDoc(containerEl, savedSel) {
        if(!containerEl) {
            console.log("containerEl not present");
            return {};
        }
        if(!saveSelection) {
            console.log("savedSel not present");
            return {};
        }
        var textRange = document.body.createTextRange();
        textRange.moveToElementText(containerEl);
        textRange.collapse(true);
        textRange.moveEnd("character", savedSel.end);
        textRange.moveStart("character", savedSel.start);
        textRange.select();
    };

    var saveSelection, restoreSelection;
    if (window.getSelection && document.createRange) {
        saveSelection = ssWindow;
        restoreSelection = rsWindow;
    } else if (document.selection && document.body.createTextRange) {
        saveSelection = ssDoc;
        restoreSelection = rsDoc
    }

    /*
    *   Logic is DOM dependent
    *   Assumes DOM elements and decides the outer container for
    *   ticket detail HTML
    */ 
    function getNoteContainer(noteElem) {
        if(!noteElem) {
            return {};
        }
        var noteDomid = noteElem.getAttribute('id');
        var c, nid, details;

        if(noteDomid === ORIGINAL_TICKET_ID) {
            c = noteElem;
        } else {
            c = noteElem.children[0];
            nid = noteElem.getAttribute('data-note-id');
        }
        return {container: c, id: nid};
    }
	
	// constructor
	function Annotation(config) {
        this.selectionInfo = {};
        this.annotationevents = config.annotationevents;
        if(!!config.wrapper_elem_style) {
            WRAPPER_ELEM_STYLE += config.wrapper_elem_style;
        }
    }

	// endpoints
    Annotation.prototype.getSelectionInfo = function(annotatorId) {
        var self = this;
        var selection = getSelection();
        var noteElem, focusNodeElem;
        var selectionInfo, selectionMeta, noteContainer, 
            anchorInsideAnnotation, focusInsideAnnotation,
            hasParentAnnotation, overlapsAnnotation;

        /*
        *   selection in main ticket description
        */ 
        if(!!selection.anchorNode && !!getParentForId(selection.anchorNode.parentNode, ORIGINAL_TICKET_ID)) {
            noteElem = !!selection.anchorNode ? getParentForId(selection.anchorNode.parentNode, ORIGINAL_TICKET_ID) : null; 
            focusNodeElem = !!selection.focusNode ? getParentForId(selection.focusNode.parentNode, ORIGINAL_TICKET_ID) : null;
        }

        /*
        *   selection in note_section
        */ 
        else {
            noteElem = !!selection.anchorNode ? getParentForClass(selection.anchorNode.parentNode, NOTE_CLASS_NAME) : null;
            focusNodeElem = !!selection.focusNode ? getParentForClass(selection.focusNode.parentNode, NOTE_CLASS_NAME) : null;
        }

        if(!!selection.anchorNode && !!selection.focusNode) {
            anchorInsideAnnotation = !!getParentForClass(selection.anchorNode, "annotation");
            focusInsideAnnotation = !!getParentForClass(selection.focusNode, "annotation");
        }

        hasParentAnnotation = anchorInsideAnnotation && focusInsideAnnotation;
        overlapsAnnotation = anchorInsideAnnotation || focusInsideAnnotation;

        var isValidSelectionEndpoints = !!noteElem && !!focusNodeElem;
        var isScopedSelection = focusNodeElem === noteElem;

        if(isValidSelectionEndpoints) {
            noteContainer = getNoteContainer(noteElem);
            selectionMeta = saveSelection(noteContainer.container);
            if (noteContainer.id) {
                selectionMeta.id = noteContainer.id;
                selectionMeta.type = "note";
            }
            selectionMeta.textContent = window.getSelection().toString().trim();
            selectionMeta.htmlContent = getSelectionHTML();
            selectionMeta.messageId = new Date().getTime();
            selectionMeta.annotatorId = annotatorId;
        }

        selectionInfo = {
            isAnnotableSelection: (!overlapsAnnotation && !hasParentAnnotation && isValidSelectionEndpoints && isScopedSelection && selectionMeta.start !== selectionMeta.end && selectionMeta.textContent !== ""),
            selectionRangeCount: selection.rangeCount,
            selectionMeta: selectionMeta,
            tempAnnotation: true,
            selectionRange: selection.rangeCount > 0  ? selection.getRangeAt(0) : {}
        };
        self.selectionInfo =  selectionInfo.isAnnotableSelection ? selectionInfo : self.selectionInfo;
        return selectionInfo;
    }
    
	/*
    *   Taken from:
    *   http://stackoverflow.com/questions/1730967/how-to-wrap-with-html-tags-a-cross-boundary-dom-selection-range#19987884
    *   http://jsfiddle.net/mayankcpdixit/2t8k59jz/
    *   Modified by freshdesk
    */
	Annotation.prototype.markAnnotation = function() {
        var self = this;
        var selection, status;
        
        function getAllDescendants (node, callback) {
            for (var i = 0; i < node.childNodes.length; i++) {
                var child = node.childNodes[i];
                getAllDescendants(child, callback);
                callback(child);
            }       
        }
        
        function glueSplitElements (firstEl, secondEl){
            var done = false,
                result = [];
            
            if(firstEl === undefined || firstEl === null || secondEl === undefined || secondEl === null){
                return false;
            }
            
            if(firstEl.nodeName === secondEl.nodeName){
                result.push([firstEl, secondEl]);
                
                while(!done){
                    firstEl = firstEl.childNodes[firstEl.childNodes.length - 1];
                    secondEl = secondEl.childNodes[0];
                    
                    if(firstEl === undefined || secondEl === undefined){
                        break;
                    }
                    
                    if(firstEl.nodeName !== secondEl.nodeName){
                        done = true;
                    } else {
                        result.push([firstEl, secondEl]);
                    }
                }
            }
            
            for(var i = result.length - 1; i >= 0; i--){
                var elements = result[i];
                while(elements[1].childNodes.length > 0){
                    elements[0].appendChild(elements[1].childNodes[0]);
                }
                elements[1].parentNode.removeChild(elements[1]);
            }
            
        }

        if(!!self.selectionInfo.isAnnotableSelection && self.selectionInfo.selectionRangeCount > 0){
            if(self.selectionInfo.selectionMeta.start === self.selectionInfo.selectionMeta.end) {
                log("%c- Not a valid selection.", ERROR_LOG_COLOR);
                return;
            }

            var range = self.selectionInfo.selectionRange,
                rangeContents = range.extractContents(),
                nodesInRange  = rangeContents.childNodes,
                nodesToWrap   = [];

            // only when it's a ticket and not a note
            if(!self.selectionInfo.selectionMeta.type && !self.selectionInfo.selectionMeta.id) {
                self.selectionInfo.selectionMeta.id = getCurrentTicketId();
                self.selectionInfo.selectionMeta.type = "ticket";
            }
            
            for(var i = 0; i < nodesInRange.length; i++){
                if(nodesInRange[i].nodeName.toLowerCase() === "#text"){
                    nodesToWrap.push(nodesInRange[i]);
                } else {
                    getAllDescendants(nodesInRange[i], function(child){
                        if(child.nodeName.toLowerCase() === "#text"){
                            nodesToWrap.push(child);
                        }
                    });
                }
            };
            
            
            for(var i = 0; i < nodesToWrap.length; i++){
                var child = nodesToWrap[i];
                var wrap = document.createElement(WRAPPER_ELEM_TAG);
                
                wrap.setAttribute("style", WRAPPER_ELEM_STYLE);
                wrap.setAttribute("data-message-id", self.selectionInfo.selectionMeta.messageId);
                wrap.setAttribute("data-annotator-id", self.selectionInfo.selectionMeta.annotatorId);
                wrap.setAttribute("id", "annotation-" + self.selectionInfo.selectionMeta.messageId);
                wrap.classList.add("annotation");
                if(self.selectionInfo.tempAnnotation) {
                    wrap.classList.add("collab-temp-annotation");
                }
                if(child.nodeValue.replace(/(\s|\n|\t)/g, "").length !== 0){
                    child.parentNode.insertBefore(wrap, child);
                    wrap.appendChild(child);

                    // add events on annotation elements 
                    for (var j = self.annotationevents.length - 1; j >= 0; j--) {
                        wrap.addEventListener(self.annotationevents[j].eventName, self.annotationevents[j].eventHandler);
                    }
                } else {
                    wrap = null;
                }
            }
            
            var firstChild = rangeContents.childNodes[0];
            var lastChild = rangeContents.childNodes[rangeContents.childNodes.length - 1];
            
            range.insertNode(rangeContents);
            
            glueSplitElements(firstChild.previousSibling, firstChild);
            glueSplitElements(lastChild, lastChild.nextSibling);
            
            rangeContents = null;
            var sel = window.document.getSelection();
            if (!detectIE() || (sel.rangeCount > 0 && sel.getRangeAt(0).getClientRects().length > 0)) {
                sel.removeAllRanges();
            }
            status = STATUS_SUCCESS;
        } else {
            log("%c- Could not annotate. Not enough data.", ERROR_LOG_COLOR, self.selectionInfo);
            status = STATUS_FAIL;
        }
        return {status: status, annotation: self.selectionInfo};
    };

	/*
    *   Taken from:
    *   http://stackoverflow.com/questions/1730967/how-to-wrap-with-html-tags-a-cross-boundary-dom-selection-range#19987884
    *   http://jsfiddle.net/mayankcpdixit/2t8k59jz/
    */
    Annotation.prototype.restoreAnnotation = function(annSelection) {
    	var self = this;
        var success = false;
        var note_hidden = false;

        annSelection = (typeof annSelection === "string") ? JSON.parse(annSelection) : annSelection;
        var container, hidden_note;
        if(annSelection.type === "note") {
            if(!!document.getElementById("note_details_" + annSelection.id)) {
                container = document.getElementById("note_details_" + annSelection.id).children[0];
            } else {
                hidden_note = true;
            }
        } else {
            container = document.getElementById(ORIGINAL_TICKET_ID);
        }

        if(!hidden_note) {
            restoreSelection(container, annSelection);
            var sel = self.getSelectionInfo(annSelection.annotatorId);
            // content match check
            if(sel.isAnnotableSelection && !!sel.selectionMeta && getTextContent(sel.selectionMeta.htmlContent) === getTextContent(annSelection.htmlContent)) {
                self.selectionInfo.tempAnnotation = false,
                self.selectionInfo.selectionMeta.messageId = annSelection.messageId;
                self.selectionInfo.selectionMeta.annotatorId = annSelection.s_id;
                self.markAnnotation();
                success = true;
            }
        } else {
            note_hidden = true;
        }

        var sel = window.document.getSelection();
        if (!detectIE() || (sel.rangeCount > 0 && sel.getRangeAt(0).getClientRects().length > 0)) {
            sel.removeAllRanges();
        }
        return {success: success, note_hidden: note_hidden};
    }

    /**
     * detect IE
     * returns version of IE or false, if browser is not Internet Explorer
     */
    function detectIE() {
        var ua = window.navigator.userAgent;

        var msie = ua.indexOf('MSIE ');
        if (msie > 0) {
            // IE 10 or older => return version number
            return parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)), 10);
        }

        var trident = ua.indexOf('Trident/');
        if (trident > 0) {
            // IE 11 => return version number
            var rv = ua.indexOf('rv:');
            return parseInt(ua.substring(rv + 3, ua.indexOf('.', rv)), 10);
        }

        var edge = ua.indexOf('Edge/');
        if (edge > 0) {
           // Edge (IE 12+) => return version number
           return parseInt(ua.substring(edge + 5, ua.indexOf('.', edge)), 10);
        }

        // other browser
        return false;
    }

    function getSelectionHTML() {
        var range = window.getSelection().getRangeAt(0),
            content = range.cloneContents(),
            span = document.createElement('SPAN');
        span.appendChild(content);
        return span.innerHTML;
    }

    function getTextContent(htmlContent) {
        var span = document.createElement('SPAN');
        span.innerHTML = htmlContent;
        return span.textContent;
    }

    return Annotation;
});

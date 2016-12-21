(function(global, LM) {
    global.lightMention = LM();
})(window, function() {
    var UNDEF = "undefined";
    var DEF_DELIMITER = "@";
    var DEF_APPENDSPACE = true;
    var DEF_MATCH_CASE = false;
    var DEF_MIN_CHAR = 0;
    var UP_KEY = 38;
    var DOWN_KEY = 40;
    var ENTER_KEY = 13;
    var SPACE_CODE = 32;
    var ENTER_CODE = 10;
    var DEF_MAX_ITEM = 10;
    var DEF_FILTER_KEYS = ["name", "uname"];
    var DEF_TAG_ATTRIBUTE = "uname";
    var DEF_MENU_HTML = "<ul id='lm-list-wrapper' class='lm-list-wrapper' style='position: absolute; background: white;border: 1px solid; padding: 2px;'></ul>";

    function setOptions(opt) {
        this.data = opt.data;
        this.editor = opt.editor;
        this.delimiter = opt.delimiter || DEF_DELIMITER;
        this.maxItems = opt.maxItems || DEF_MAX_ITEM;
        this.filterKeys = opt.filterKeys || DEF_FILTER_KEYS;
        this.menuHtml = opt.menuHtml || DEF_MENU_HTML;
        this.tagAttribute = opt.tagAttribute || DEF_TAG_ATTRIBUTE;

        this.appendSpace = typeof opt.appendSpace === UNDEF ? DEF_APPENDSPACE : opt.appendSpace;
        this.minChar = typeof opt.minChar === UNDEF ? DEF_MIN_CHAR : opt.minChar;
        this.matchCase = typeof opt.matchCase === UNDEF ? DEF_MATCH_CASE : opt.matchCase;
    }

    // constructor
    function lightMention(opt) {
        var self = this;
        self.replaceeMeta = {};
        self.listShown = false;

        setOptions.call(self, opt);
        console.log("LM inited");
    }

    lightMention.prototype.bindMention = function() {
        var self = this;
        var el = document.querySelector(self.editor);
        if(!!el) {
            el.addEventListener("keydown", function(event) {
                var selection_key_pressed = event.keyCode === UP_KEY 
                    || event.keyCode === DOWN_KEY
                    || (event.keyCode === ENTER_KEY && !event.shiftKey);
                if(!!self.listShown && selection_key_pressed) {
                    selectOnAction.call(self, event);
                }
            });
            el.addEventListener("keyup", function(event) {
                var selection_key_pressed = event.keyCode === UP_KEY 
                    || event.keyCode === DOWN_KEY
                    || (event.keyCode === ENTER_KEY && !event.shiftKey);
                if(!self.listShown || !selection_key_pressed) {
                    var replacee = getReplacee.call(self, event);
                    if(!!replacee) {
                        var filtered_list = filter.call(self, event, replacee);
                        var already_typed = filtered_list.length === 1 && filtered_list[0][self.tagAttribute] === replacee.substring(1);
                        if(filtered_list.length && !already_typed) {
                            render.call(self, event, filtered_list);
                            self.listShown = true;
                            activateListeners.call(self);
                        } else {
                            hideLmList.call(self);
                        }
                    } else {
                        hideLmList.call(self);
                    }
                }
            });
        }
    }

    function hideOnClickOutside (event) {
        var self = this;

        if(self.listShown) {
            hideLmList.call(self);
        }
    }

    function activateListeners() {
        var self = this;
        document.addEventListener('click', function(event) {
            hideOnClickOutside.call(self, event);
        });
    }

    function hoverPrevElem() {
        var cur_selected = document.querySelector(".lm-list-item.selected");
        if(cur_selected.previousElementSibling) {
            cur_selected.classList.remove("selected");
            cur_selected.previousElementSibling.classList.add("selected");
        }
    }
    function hoverNextElem() {
        var cur_selected = document.querySelector(".lm-list-item.selected");
        if(cur_selected.nextElementSibling) {
            cur_selected.classList.remove("selected");
            cur_selected.nextElementSibling.classList.add("selected");
        }
    }
    function hoverHoveredElem(event) {
        var cur_selected = document.querySelector(".lm-list-item.selected");
        cur_selected.classList.remove("selected");
        event.target.classList.add("selected");
    
    }

    function pushSelectedElem() {
        var self = this;

        if(!!self.replaceeMeta.replacee && self.replaceeMeta.valid) {
            var cur_selected = document.querySelector(".lm-list-item.selected");
            var replacer = cur_selected.getAttribute("data-lm-tag");
            if(!!replacer) {
                if(self.appendSpace && self.replaceeMeta.noCharPostCursor) {
                    replacer =  replacer + " ";
                }
                var el = document.querySelector(self.editor)
                var text_content = el.value;
                text_before = text_content.substring(0, self.replaceeMeta.index);
                text_after = text_content.substring(self.replaceeMeta.caretPos);
                text_content = text_before + self.delimiter + replacer + text_after;
                el.value = text_content;
                hideLmList.call(self);
                restoreCaretPos.call(self);
            }
        }
    }

    function selectOnAction(event) {
        var self = this;
        if(!event.shiftKey) {
            switch (event.keyCode) {
                case UP_KEY: {
                    event.preventDefault();
                    hoverPrevElem();
                    break;
                }
                case DOWN_KEY: {
                    event.preventDefault();
                    hoverNextElem();
                    break;
                }
                case ENTER_KEY: {
                    event.preventDefault();
                    pushSelectedElem.call(self);
                    event.stopPropagation();
                    break;
                }
            }
        }
    }

    function getReplacee(event) {
        var self = this;

        var valid_replacee;
        var replacee = "";
        var delimiter = self.delimiter;
        var input_elem = event.currentTarget;
        var caret_pos = GetCaretPosition(input_elem);
        var text_content = input_elem.value;

        var char_next_to_caret = text_content.charCodeAt(caret_pos);
        var valid_following = isNaN(char_next_to_caret) || char_next_to_caret == SPACE_CODE || char_next_to_caret == ENTER_CODE;
        
        if(valid_following) {
            for (var i = caret_pos; i >= 0; i--) {
                if (text_content[i] == delimiter) {
                    break;
                }
            }

            var before_line_starts = (i === -1);

            var char_before_delimiter = text_content.charCodeAt(i-1);
            var valid_preceding = isNaN(char_before_delimiter) || char_before_delimiter == SPACE_CODE || char_before_delimiter == ENTER_CODE;

            replacee = text_content.substring(i, caret_pos);
            valid_replacee = replacee.indexOf(" ") < 0 && !before_line_starts && valid_preceding;

            if(self.minChar) {
                valid_replacee = valid_replacee && (replacee.length > self.minChar);
            }

            self.replaceeMeta = {
                index: i,
                replacee: replacee,
                valid: valid_replacee,
                caretPos: caret_pos,
                noCharPostCursor: isNaN(char_next_to_caret)
            }
        } else {
            self.replaceeMeta = {};
        }

        return valid_replacee ? replacee : "";
    }

    function filter(event, item) {
        var self = this;

        data = self.data;
        item = item.substring(1);
        var res = [];

        for(var user_json_idx = 0; user_json_idx < data.length; user_json_idx++) {
            var user_json = data[user_json_idx];

            for(var filter_key_idx = 0; filter_key_idx < self.filterKeys.length; filter_key_idx++) {
                var filter_key = self.filterKeys[filter_key_idx];

                var target = !!self.matchCase ? user_json[filter_key] : (user_json[filter_key] ? user_json[filter_key].toLowerCase() : "");
                var item_to_check = !!self.matchCase ? item : item.toLowerCase();
                if(target.indexOf(item_to_check) >= 0) {
                    res.push(data[user_json_idx]);
                    break;
                }
            }
        }
        // TODO (mayank): sort this;
        return res.splice(0, self.maxItems);
    }

    function render(event, list) {
        var self = this;

        hideLmList.call(self);

        var el = document.querySelector(self.editor);
        var lm_menu_node = self.menuHtml;
        insertAfter(lm_menu_node, el);

        lm_menu_node = el.nextSibling;
        lm_menu_node.classList.add("lm-list-wrapper");
        lm_menu_node.setAttribute("style", (lm_menu_node.getAttribute("style") || "") + "display: none;");
        
        var ul = (lm_menu_node.tagName.toLowerCase() === "ul") ? lm_menu_node : lm_menu_node.querySelector("ul");

        for(var i=0; i<list.length; i++) {
            var li = document.createElement("li");
            var c_name = (i===0) ? "lm-list-item selected" : "lm-list-item";
            li.setAttribute("class", c_name);
            // li.setAttribute("data-lm-tag", list[i][self.tagAttribute]);
            // li.innerHTML = list[i][self.tagAttribute];

            li.setAttribute("data-lm-tag", list[i][self.tagAttribute] || list[i].mention_text); // Added by FD
            li.innerHTML = JST["collaboration/templates/collaborators_list_item"]({ "data": list[i]}); // Added by FD
            
            li.addEventListener("click", function(event) {
                pushSelectedElem.call(self);
            });

            li.addEventListener("mouseenter", function(event) {
                hoverHoveredElem(event);
            });
            ul.appendChild(li);
        }

        var el = document.querySelector(self.editor);
        var bottom_margin = el.offsetHeight;
        lm_menu_node.setAttribute("style", (lm_menu_node.getAttribute("style") || "") + "bottom:" + bottom_margin + "px;");
        lm_menu_node.setAttribute("style", (lm_menu_node.getAttribute("style") || "").replace(/display: none;/gi, ""));
    }

    function GetCaretPosition(ctrl) {
        var CaretPos = 0;   // IE Support
        if (document.selection) {
            ctrl.focus();
            var Sel = document.selection.createRange();
            Sel.moveStart('character', -ctrl.value.length);
            CaretPos = Sel.text.length;
        }
        // Firefox support
        else if (ctrl.selectionStart || ctrl.selectionStart == '0')
            CaretPos = ctrl.selectionStart;
        return (CaretPos);
    }

    function hideLmList() {
        var self = this;

        var lm_menu_node = document.getElementsByClassName("lm-list-wrapper")[0];
        if(lm_menu_node) {
            lm_menu_node.parentNode.removeChild(lm_menu_node);
            self.listShown = false;
        }
    }

    function insertAfter(newNode, referenceNode) {
        if(typeof newNode === "string") {
            referenceNode.insertAdjacentHTML('afterend', newNode);
        } else {
            referenceNode.parentNode.insertBefore(newNode, referenceNode.nextSibling);
        }
    }

    // TODO (mayank): make it work for real
    function restoreCaretPos() {
        var self = this;
        var el = document.querySelector(self.editor);
        el.focus();
    }

    function getParents(el, parentSelector /* optional */) {
        // If no parentSelector defined will bubble up all the way to *document*
        if (parentSelector === undefined) {
            parentSelector = document;
        }

        var parents = [];
        var p = el.parentNode;

        while (p !== parentSelector) {
            if(!!p) {
                var o = p;
                parents.push(o);
                p = o.parentNode;
            } else {
                break;
            }
        }
        parents.push(parentSelector); // Push that parentSelector you wanted to stop at

        return parents;
    }

    return lightMention;
});

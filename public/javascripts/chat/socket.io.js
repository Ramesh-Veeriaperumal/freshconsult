var io = "undefined" == typeof module ? {} : module.exports;
(function () {
        (function (a, b) {
                var c = a;
                c.version = "0.9.11", c.protocol = 1, c.transports = [], c.j = [], c.sockets = {}, c.connect = function (a, d) {
                    var e = c.util.parseUri(a),
                        f, g;
                    b && b.location && (e.protocol = e.protocol || b.location.protocol.slice(0, -1), e.host = e.host || (b.document ? b.document.domain : b.location.hostname), e.port = e.port || b.location.port), f = c.util.uniqueUri(e);
                    var h = {
                        host: e.host,
                        secure: "https" == e.protocol,
                        port: e.port || ("https" == e.protocol ? 443 : 80),
                        query: e.query || ""
                    };
                    c.util.merge(h, d);
                    if (h["force new connection"] || !c.sockets[f]) g = new c.Socket(h);
                    return !h["force new connection"] && g && (c.sockets[f] = g), g = g || c.sockets[f], g.of(e.path.length > 1 ? e.path : "")
                }
            })("object" == typeof module ? module.exports : this.io = {}, this),
        function (a, b) {
            var c = a.util = {}, d = /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/,
                e = ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "anchor"];
            c.parseUri = function (a) {
                var b = d.exec(a || ""),
                    c = {}, f = 14;
                while (f--) c[e[f]] = b[f] || "";
                return c
            }, c.uniqueUri = function (a) {
                var c = a.protocol,
                    d = a.host,
                    e = a.port;
                return "document" in b ? (d = d || document.domain, e = e || (c == "https" && document.location.protocol !== "https:" ? 443 : document.location.port)) : (d = d || "localhost", !e && c == "https" && (e = 443)), (c || "http") + "://" + d + ":" + (e || 80)
            }, c.query = function (a, b) {
                var d = c.chunkQuery(a || ""),
                    e = [];
                c.merge(d, c.chunkQuery(b || ""));
                for (var f in d) d.hasOwnProperty(f) && e.push(f + "=" + d[f]);
                return e.length ? "?" + e.join("&") : ""
            }, c.chunkQuery = function (a) {
                var b = {}, c = a.split("&"),
                    d = 0,
                    e = c.length,
                    f;
                for (; d < e; ++d) f = c[d].split("="), f[0] && (b[f[0]] = f[1]);
                return b
            };
            var f = !1;
            c.load = function (a) {
                if ("document" in b && document.readyState === "complete" || f) return a();
                c.on(b, "load", a, !1)
            }, c.on = function (a, b, c, d) {
                a.attachEvent ? a.attachEvent("on" + b, c) : a.addEventListener && a.addEventListener(b, c, d)
            }, c.request = function (a) {
                if (a && "undefined" != typeof XDomainRequest && !c.ua.hasCORS) return new XDomainRequest;
                if ("undefined" != typeof XMLHttpRequest && (!a || c.ua.hasCORS)) return new XMLHttpRequest;
                if (!a) try {
                        return new(window[["Active"].concat("Object").join("X")])("Microsoft.XMLHTTP")
                } catch (b) {}
                return null
            }, "undefined" != typeof window && c.load(function () {
                    f = !0
                }), c.defer = function (a) {
                if (!c.ua.webkit || "undefined" != typeof importScripts) return a();
                c.load(function () {
                        setTimeout(a, 100)
                    })
            }, c.merge = function (b, d, e, f) {
                var g = f || [],
                    h = typeof e == "undefined" ? 2 : e,
                    i;
                for (i in d) d.hasOwnProperty(i) && c.indexOf(g, i) < 0 && (typeof b[i] != "object" || !h ? (b[i] = d[i], g.push(d[i])) : c.merge(b[i], d[i], h - 1, g));
                return b
            }, c.mixin = function (a, b) {
                c.merge(a.prototype, b.prototype)
            }, c.inherit = function (a, b) {
                function c() {}
                c.prototype = b.prototype, a.prototype = new c
            }, c.isArray = Array.isArray || function (a) {
                return Object.prototype.toString.call(a) === "[object Array]"
            }, c.intersect = function (a, b) {
                var d = [],
                    e = a.length > b.length ? a : b,
                    f = a.length > b.length ? b : a;
                for (var g = 0, h = f.length; g < h; g++)~ c.indexOf(e, f[g]) && d.push(f[g]);
                return d
            }, c.indexOf = function (a, b, c) {
                for (var d = a.length, c = c < 0 ? c + d < 0 ? 0 : c + d : c || 0; c < d && a[c] !== b; c++);
                return d <= c ? -1 : c
            }, c.toArray = function (a) {
                var b = [];
                for (var c = 0, d = a.length; c < d; c++) b.push(a[c]);
                return b
            }, c.ua = {}, c.ua.hasCORS = "undefined" != typeof XMLHttpRequest && function () {
                try {
                    var a = new XMLHttpRequest
                } catch (b) {
                    return !1
                }
                return a.withCredentials != undefined
            }(), c.ua.webkit = "undefined" != typeof navigator && /webkit/i.test(navigator.userAgent), c.ua.iDevice = "undefined" != typeof navigator && /iPad|iPhone|iPod/i.test(navigator.userAgent)
        }("undefined" != typeof io ? io : module.exports, this),
        function (a, b) {
            function c() {}
            a.EventEmitter = c, c.prototype.on = function (a, c) {
                return this.$events || (this.$events = {}), this.$events[a] ? b.util.isArray(this.$events[a]) ? this.$events[a].push(c) : this.$events[a] = [this.$events[a], c] : this.$events[a] = c, this
            }, c.prototype.addListener = c.prototype.on, c.prototype.once = function (a, b) {
                function d() {
                    c.removeListener(a, d), b.apply(this, arguments)
                }
                var c = this;
                return d.listener = b, this.on(a, d), this
            }, c.prototype.removeListener = function (a, c) {
                if (this.$events && this.$events[a]) {
                    var d = this.$events[a];
                    if (b.util.isArray(d)) {
                        var e = -1;
                        for (var f = 0, g = d.length; f < g; f++) if (d[f] === c || d[f].listener && d[f].listener === c) {
                                e = f;
                                break
                            }
                        if (e < 0) return this;
                        d.splice(e, 1), d.length || delete this.$events[a]
                    } else(d === c || d.listener && d.listener === c) && delete this.$events[a]
                }
                return this
            }, c.prototype.removeAllListeners = function (a) {
                return a === undefined ? (this.$events = {}, this) : (this.$events && this.$events[a] && (this.$events[a] = null), this)
            }, c.prototype.listeners = function (a) {
                return this.$events || (this.$events = {}), this.$events[a] || (this.$events[a] = []), b.util.isArray(this.$events[a]) || (this.$events[a] = [this.$events[a]]), this.$events[a]
            }, c.prototype.emit = function (a) {
                if (!this.$events) return !1;
                var c = this.$events[a];
                if (!c) return !1;
                var d = Array.prototype.slice.call(arguments, 1);
                if ("function" == typeof c) c.apply(this, d);
                else {
                    if (!b.util.isArray(c)) return !1;
                    var e = c.slice();
                    for (var f = 0, g = e.le...inherit(c, b.Transport.XHR), c.prototype.name = "htmlfile", c.prototype.get = function () {
                                this.doc = new(window[["Active"].concat("Object").join("X")])("htmlfile"), this.doc.open(), this.doc.write("<html></html>"), this.doc.close(), this.doc.parentWindow.s = this;
                                var a = this.doc.createElement("div");
                                a.className = "socketio", this.doc.body.appendChild(a), this.iframe = this.doc.createElement("iframe"), a.appendChild(this.iframe);
                                var c = this,
                                    d = b.util.query(this.socket.options.query, "t=" + +(new Date));
                                this.iframe.src = this.prepareUrl() + d, b.util.on(window, "unload", function () {
                                        c.destroy()
                                    })
                            }, c.prototype._ = function (a, b) {
                                this.onData(a);
                                try {
                                    var c = b.getElementsByTagName("script")[0];
                                    c.parentNode.removeChild(c)
                                } catch (d) {}
                            }, c.prototype.destroy = function () {
                                if (this.iframe) {
                                    try {
                                        this.iframe.src = "about:blank"
                                    } catch (a) {}
                                    this.doc = null, this.iframe.parentNode.removeChild(this.iframe), this.iframe = null, CollectGarbage()
                                }
                            }, c.prototype.close = function () {
                                return this.destroy(), b.Transport.XHR.prototype.close.call(this)
                            }, c.check = function (a) {
                                if (typeof window != "undefined" && ["Active"].concat("Object").join("X") in window) try {
                                        var c = new(window[["Active"].concat("Object").join("X")])("htmlfile");
                                        return c && b.Transport.XHR.check(a)
                                } catch (d) {}
                                return !1
                            }, c.xdomainCheck = function () {
                                return !1
                            }, b.transports.push("htmlfile")
                    }("undefined" != typeof io ? io.Transport : module.exports, "undefined" != typeof io ? io : module.parent.exports),
                    function (a, b, c) {
                        function d() {
                            b.Transport.XHR.apply(this, arguments)
                        }

                        function e() {}
                        a["xhr-polling"] = d, b.util.inherit(d, b.Transport.XHR), b.util.merge(d, b.Transport.XHR), d.prototype.name = "xhr-polling", d.prototype.heartbeats = function () {
                            return !1
                        }, d.prototype.open = function () {
                            var a = this;
                            return b.Transport.XHR.prototype.open.call(a), !1
                        }, d.prototype.get = function () {
                            function b() {
                                this.readyState == 4 && (this.onreadystatechange = e, this.status == 200 ? (a.onData(this.responseText), a.get()) : a.onClose())
                            }

                            function d() {
                                this.onload = e, this.onerror = e, a.retryCounter = 1, a.onData(this.responseText), a.get()
                            }

                            function f() {
                                a.retryCounter++, !a.retryCounter || a.retryCounter > 3 ? a.onClose() : a.get()
                            }
                            if (!this.isOpen) return;
                            var a = this;
                            this.xhr = this.request(), c.XDomainRequest && this.xhr instanceof XDomainRequest ? (this.xhr.onload = d, this.xhr.onerror = f) : this.xhr.onreadystatechange = b, this.xhr.send(null)
                        }, d.prototype.onClose = function () {
                            b.Transport.XHR.prototype.onClose.call(this);
                            if (this.xhr) {
                                this.xhr.onreadystatechange = this.xhr.onload = this.xhr.onerror = e;
                                try {
                                    this.xhr.abort()
                                } catch (a) {}
                                this.xhr = null
                            }
                        }, d.prototype.ready = function (a, c) {
                            var d = this;
                            b.util.defer(function () {
                                    c.call(d)
                                })
                        }, b.transports.push("xhr-polling")
                    }("undefined" != typeof io ? io.Transport : module.exports, "undefined" != typeof io ? io : module.parent.exports, this),
                    function (a, b, c) {
                        function e(a) {
                            b.Transport["xhr-polling"].apply(this, arguments), this.index = b.j.length;
                            var c = this;
                            b.j.push(function (a) {
                                    c._(a)
                                })
                        }
                        var d = c.document && "MozAppearance" in c.document.documentElement.style;
                        a["jsonp-polling"] = e, b.util.inherit(e, b.Transport["xhr-polling"]), e.prototype.name = "jsonp-polling", e.prototype.post = function (a) {
                            function i() {
                                j(), c.socket.setBuffer(!1)
                            }

                            function j() {
                                c.iframe && c.form.removeChild(c.iframe);
                                try {
                                    h = document.createElement('<iframe name="' + c.iframeId + '">')
                                } catch (a) {
                                    h = document.createElement("iframe"), h.name = c.iframeId
                                }
                                h.id = c.iframeId, c.form.appendChild(h), c.iframe = h
                            }
                            var c = this,
                                d = b.util.query(this.socket.options.query, "t=" + +(new Date) + "&i=" + this.index);
                            if (!this.form) {
                                var e = document.createElement("form"),
                                    f = document.createElement("textarea"),
                                    g = this.iframeId = "socketio_iframe_" + this.index,
                                    h;
                                e.className = "socketio", e.style.position = "absolute", e.style.top = "0px", e.style.left = "0px", e.style.display = "none", e.target = g, e.method = "POST", e.setAttribute("accept-charset", "utf-8"), f.name = "d", e.appendChild(f), document.body.appendChild(e), this.form = e, this.area = f
                            }
                            this.form.action = this.prepareUrl() + d, j(), this.area.value = b.JSON.stringify(a);
                            try {
                                this.form.submit()
                            } catch (k) {}
                            this.iframe.attachEvent ? h.onreadystatechange = function () {
                                c.iframe.readyState == "complete" && i()
                            } : this.iframe.onload = i, this.socket.setBuffer(!0)
                        }, e.prototype.get = function () {
                            var a = this,
                                c = document.createElement("script"),
                                e = b.util.query(this.socket.options.query, "t=" + +(new Date) + "&i=" + this.index);
                            this.script && (this.script.parentNode.removeChild(this.script), this.script = null), c.async = !0, c.src = this.prepareUrl() + e, c.onerror = function () {
                                a.onClose()
                            };
                            var f = document.getElementsByTagName("script")[0];
                            f.parentNode.insertBefore(c, f), this.script = c, d && setTimeout(function () {
                                    var a = document.createElement("iframe");
                                    document.body.appendChild(a), document.body.removeChild(a)
                                }, 100)
                        }, e.prototype._ = function (a) {
                            return this.onData(a), this.isOpen && this.get(), this
                        }, e.prototype.ready = function (a, c) {
                            var e = this;
                            if (!d) return c.call(this);
                            b.util.load(function () {
                                    c.call(e)
                                })
                        }, e.check = function () {
                            return "document" in c
                        }, e.xdomainCheck = function () {
                            return !0
                        }, b.transports.push("jsonp-polling")
                    }("undefined" != typeof io ? io.Transport : module.exports, "undefined" != typeof io ? io : module.parent.exports, this), typeof define == "function" && define.amd && define([], function () {
                            return io
                        })
                })()
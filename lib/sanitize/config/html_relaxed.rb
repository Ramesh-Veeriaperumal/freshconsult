#--
# Copyright (c) 2011 Ryan Grove <ryan@wonko.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

class Sanitize
  module Config
    HTML_RELAXED = {
      :elements => %w[
        a abbr acronym address audio b bdo blockquote br caption cite code col colgroup dd del details dfn dl div
        dt em font figcaption figure h1 h2 h3 h4 h5 h6 hgroup hr i img ins kbd li mark
        ol p pre q rp rt ruby s samp section summary small strike strong sub sup table tbody td
        tfoot th thead time tr tt u ul var wbr span source video
      ],
      :remove_contents => [ 'style','title','script' ],
      :attributes => {
        :all         => ['dir', 'lang', 'title','style', 'id', 'align', 'class', 'rel'],
        'a'          => ['href','target','download'],
        'blockquote' => ['cite',"class"],
        'col'        => ['span', 'width'],
        'colgroup'   => ['span', 'width'],
        'del'        => ['cite', 'datetime'],
        'img'        => ['align', 'alt', 'height', 'src', 'width', 'class', 'data-id', 'data-height'],
        'ins'        => ['cite', 'datetime'],
        'ol'         => ['start', 'reversed', 'type'],
        'q'          => ['cite'],
        'table'      => ['summary', 'width', 'border', 'cellspacing', 'cellpadding'],
        'td'         => ['abbr', 'axis', 'colspan', 'rowspan', 'width'],
        'th'         => ['abbr', 'axis', 'colspan', 'rowspan', 'scope', 'width'],
        'time'       => ['datetime', 'pubdate'],
        'ul'         => ['type'],
        'div'        => ['class'],
        'source'     => ['src', 'type'],
        'audio'      => ['controls', 'width', 'height'],
        'video'      => ['src', 'width', 'height', 'crossorigin', 'poster', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted', 'controls'],
        'pre'        => ['rel','code-brush'],
        'font'       => ['color']
      },
      :add_attributes => {
        'a' => {'rel' => 'noreferrer'}
      },
      :protocols => {
        'a'          => {'href' => ['ftp', 'http', 'https', 'mailto', 'tel', 'callto', :relative], 'target' => ['_blank','_self','_parent','_top',:relative]},
        'blockquote' => {'cite' => ['http', 'https', :relative]},
        'del'        => {'cite' => ['http', 'https', :relative]},
        'img'        => {'src'  => ['http', 'https', :relative]},
        'ins'        => {'cite' => ['http', 'https', :relative]},
        'q'          => {'cite' => ['http', 'https', :relative]},
        'source'     => {'src'	=> ['http', 'https']},
      }
    }
  end
end

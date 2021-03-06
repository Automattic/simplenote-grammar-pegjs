{
	function offsets(l) {
		return [
        	l.start.offset,
            l.end.offset
		]
	}
}

Lines
	= ls:(l:Line EOL { return l })* l:Line { return ls.concat( l ) }

Line
	= Header
    / BlockQuote
    / ts:Token*
    {
        const tokens = ts.reduce(
        	function(out, next) {
            	return typeof next === 'string' && typeof out[1] === 'string'
                	? [ out[0].slice(0, -1).concat( out[0].slice(-1).concat( next ).join('') ), next ]
                    : [ out[0].concat( next ), next ];
            },
            [[], undefined]
        )

        return tokens[0].map( function( token ) {
        	const value = typeof token === 'string'
            	? { type: 'text', text: token }
                : token;

            return Object.assign( { location: offsets( location() ) }, value )
        } )
    }

Header
	= l:(h:'#'+ { return { hs: h, location: location() } }) t:[^\n]*
    & { return l.hs.length <= 6 }
    { return {
    	type: 'header',
        level: l.hs.length,
        text: t.join(''),
        location: offsets( location() ),
        hashLocation: offsets( l.location )
    } }

BlockQuote
	= i:BlockQuoteIndents _* q:[^\n]+
    { return {
    	type: 'blockquote',
        text: q.join(''),
        level: i.level,
        location: offsets( location() ),
        indentLocation: i.location,
    } }
    
BlockQuoteIndents
	= '>' l:(_* b:'>')*
    { return {
    	level: 1 + l.length,
        location: offsets( location() )
    } }

BulletItem
	= s:(__ { return location() }) b:([-*] { return location() }) ' '
    & { return s.start.column === 1 }
    { return {
    	type: 'list-bullet',
        location: offsets( location() ),
        bulletLocation: offsets( b )
    } }

ToDoItem
	= s:(__ { return location() }) b:('- [' d:(d:[xX]/d:' ' { return d }) ']' { return { isDone: d !== ' ', l: location() } } ) __
    & { return s.start.column === 1 }
    { return {
    	type: 'todo-bullet',
        isDone: b.isDone,
        location: offsets( location() ),
        bulletLocation: offsets( b.l )
    } }

Token
	= ToDoItem
    / BulletItem
    / HtmlLink
    / MarkdownLink
    / Url
    / SchemalessUrl
    / Strong
    / Emphasized
    / StrikeThrough
    / InlineCode
    / AtMention
    / [^\n]

Strong
	= '**' s:(!'**' c:. { return c })+ '**'
    { return {
    	type: 'strong',
        text: s.join(''),
        location: offsets( location() )
	} }
    
    / '__' s:(!'__' c:. { return c })+ '__'
    { return {
    	type: 'strong',
        text: s.join(''),
        location: offsets( location() )
	} }

Emphasized
	= '*' s:[^*]+ '*'
    { return {
    	type: 'em',
        text: s.join(''),
        location: offsets( location() )
	} }
    
    / '_' s:[^_]+ '_'
    { return {
    	type: 'em',
        text: s.join(''),
        location: offsets( location() )
	} }

StrikeThrough
	= '~~' s:(!'~~' c:. { return c })+ '~~'
    { return {
    	type: 'strike',
        text: s.join(''),
        location: offsets( location() )
	} }

InlineCode
	= '`' s:[^`]+ '`'
    { return {
    	type: 'code-inline',
        text: s.join(''),
        location: offsets( location() )
	} }

AtMention
    = /* AtMention cannot follow mention-able character */
      c:[a-z0-9_] '@'
    { return c + '@' }
    
    / at:('@' { return offsets( location() ) } ) head:[a-z]i tail:[a-z0-9_]i*
    { return {
    	type: 'at-mention',
        text: [head].concat(tail).join(''),
        location: offsets( location() ),
        atLocation: at
	} }

Url
	= scheme:UrlScheme '://' u:SchemalessUrl
    { return {
    	type: 'link',
        url: scheme + '://' + u.url,
        urlLocation: offsets( location() ),
        location: offsets( location() )
    } }

UrlScheme
	= s:[a-z]i ss:[a-z0-9+\.\-]i+
    { return s + ss.join('') }

UrlHost
	= UrlIpHost
    
    / u:UrlHostPart '.' t:TLD
    { return u + '.' + t }

    / pp:UrlHostPart ps:(!('.' TLD) '.' p:UrlHostPart { return p })* '.' t:TLD
    { return [pp].concat( ps ).concat( t ).join('.') }
    
UrlIpHost
	= a:IPNum '.' b:IPNum '.' c:IPNum '.' d:IPNum
    { return [a,b,c,d].join('.') }

IPNum
	= ds:[0-9]+
    & {
      try {
        return parseInt( ds.join(''), 10 ) < 256;
      } catch (e) {
        return false;
      }
    }
    { return ds.join('') }

UrlHostPart
    = cs:[0-9a-z\-_~]i+
    { return cs.join('') }

UrlPath
	= ps:(p:UrlPathPart t:'/'? { return [p, t].join('') })+
    { return ps.join('') }

UrlPathPart
	= c:UrlPathChar+ cs:('.' ccs:UrlPathChar+ { return '.' + ccs.join('') })*
    { return [c.join('')].concat( cs ).join('') }

UrlPathChar
	= [a-z0-9\-_~()!$&'*+,;=]i
    
UrlQuery
	= '?' as:[a-z0-9$&%-_\.+=?/!()*',;]i+
    { return '?' + as.join('') }
    
UrlFragment
	= '#' fs:[a-z0-9$&%\-_\.+=?/!()*,;'#]i*
    { return '#' + fs.join('') }
    
UrlAuth
	= un:(u:[a-z]i us:[a-z0-9;?&=]i+ { return u + us.join('') })
      pw:(':' p:[a-z]i ps:[a-z0-9;?&=]i+ { return p + ps.join('') })? '@'
    { return pw ? un + ':' + pw + '@' : un + '@' }
    
SchemalessUrl
    = auth:UrlAuth?
      h:UrlHost !UrlHostPart !('.' UrlHostPart)
      port:(':' d:[0-9]+ { return ':' + d.join('') })?
      slash:'/'? 
      path:UrlPath? 
      query:UrlQuery?
      fragment:UrlFragment?
    { return {
    	type: 'link',
        url: [ auth, h, port, slash, path, query, fragment ].join(''),
        urlLocation: offsets( location() ),
        location: offsets( location() )
    } }
    
TLD
	= 'com'i
    / 'org'i
    / 'net'i
    / 'int'i
    / 'edu'i
    / 'gov'i
    / 'mil'i
    / 'arpa'i
    / CCTLD
    / GTLD
    
CCTLD
	= 'a' c:[cdefgilmnoqrstuwxz] { return 'a' + c }
    / 'b' c:[abdefghijmnoqrstvwz] { return 'b' + c }
    / 'c' c:[acdfghiklmnoruvwxyz] { return 'c' + c }
    / 'd' c:[ejkmoz] { return 'd' + c }
    / 'e' c:[ceghrstu] { return 'e' + c }
    / 'f' c:[ijkmor] { return 'f' + c }
	/ 'g' c:[abdefghilmnpqrstuwy] { return 'g' + c }
    / 'h' c:[kmnrtu] { return 'h' + c }
    / 'i' c:[delmnoqrst] { return 'i' + c }
    / 'j' c:[emop] { return 'j' + c }
    / 'k' c:[eghimnprwyz] { return 'k' + c }
    / 'l' c:[abcikrstuvy] { return 'l' + c }
    / 'm' c:[acdeghklmnopqrstuvwxyz] { return 'm' + c }
    / 'n' c:[acefgilopruz] { return 'n' + c }
    / 'om'
    / 'p' c:[aefghklmnrstwy] { return 'p' + c }
    / 'qa'
    / 'r' c:[eosuw] { return 'r' + c }
    / 's' c:[abcdeghijklmnorstuvxyz] { return 's' + c }
    / 't' c:[cdfghjklmnoprtvwz] { return 't' + c }
    / 'u' c:[agksyz] { return 'u' + c }
    / 'v' c:[aceginu] { return 'v' + c }
    / 'w' c:[fs] { return 'w' + c }
    / 'y' c:[et] { return 'y' + c }
    / 'z' c:[amw] { return 'z' + c }
    
GTLD
	= 'academy'
    / 'accountant'
    / 'accountants'
    / 'active'
    / 'actor'
    / 'adult'
    / 'aero'
    / 'agency'
    / 'airforce'
    / 'apartments'
    / 'app'
    / 'archi'
    / 'bar'
    / 'biz'
    / 'blog'
    / 'coffee'
    / 'info'
    / 'lol'
    / 'mobi'
    / 'travel'
    / 'sucks'
    / 'ws'
    
HtmlLink
	= '<a' __ al:HtmlAttributeList '/'? '>' text:(t:(!'</a>' c:. { return c })+ { return { t: t, l: location() } }) '</a>'
    { return {
    	type: 'link',
        text: text.t.join(''),
        url: al.find( a => 'href' === a.name ).value,
        urlLocation: al.find( a => 'href' === a.name ).location,
        titleLocation: offsets( text.l ),
        location: offsets( location() )
    } }
    
HtmlAttributeList
	= as:(a:HtmlAttribute __ { return a })* a:HtmlAttribute?
    { return as.concat( a ) }

HtmlAttribute
	= name:[a-zA-Z]+ '=' value:(v:QuotedString { return { v: v.s, l: v.l } })
    { return {
    	name: name.join(''),
        value: value.v,
        location: value.l
    } }

QuotedString
	= '"' string:(s:('\\"' / !'"' c:. { return c })* { return { v: s.join(''), l: location() } }) '"'
    { return { s: string.v, l: offsets( string.l ) } }
    
    / "'" string:(s:("\\'" / !"'" c:. { return c })* { return { v: s.join(''), l: location() } }) "'"
    { return { s: string.v, l: offsets( string.l ) } }

MarkdownLink
	= t:MarkdownLinkTitle u:MarkdownLinkUrl
    { return {
    	type: 'link',
        text: t.text,
        linkTitleLocation: t.location,
        titleLocation: t.textLocation,
        url: u.url,
        linkLocation: u.location,
        urlLocation: u.urlLocation,
        location: offsets( location() )
    } }
    
MarkdownLinkTitle
	= '[' t:(t:[^\]]+ { return { t: t, l: location() } }) ']'
    { return {
    	text: t.t.join(''),
        textLocation: offsets( t.l ),
        location: offsets( location() )
    } }
    
MarkdownLinkUrl
	= '(' url:(u:[^\)]+ { return { u: u, l: location() } }) ')'
    { return {
    	url: url.u.join(''),
        urlLocation: offsets( url.l ),
        location: offsets( location() )
    } }

EOL
	= [\n]

__
	= _+

_
	= [ \t]
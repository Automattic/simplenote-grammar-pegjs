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
    / RFC1738Url
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

RFC1738Url
	= UrlHttpUrl

UrlHttpUrl
	= scheme:('http' 's'? '://')
      hp:UrlHostPort
      path:('/' p:UrlHostPath search:('?' s:UrlSearch { return '?' + s })? 
      { return ['/', p, search].join('')})?
    { return {
    	type: 'link',
        url: [scheme.join(''), hp, path].join(''),
        location: offsets( location() ),
        urlLocation: offsets( location() )
    } }
    
UrlHostPath
	= head:UrlHostPathSegment tail:('/' h:UrlHostPathSegment { return '/' + h })*
    { return head + tail.join('') }
    
UrlHostPathSegment
	= s:(UrlUChar / [;:@&=])*
    { return s.join('') }
    
UrlSearch
	= s:(UrlUChar / [;:@&=])*
    { return s.join('') }

UrlHostPort
	= h:(UrlHostNumber / UrlHostname) p:(':' ds:Digit+ { return ':' + ds.join('') })?
    { return [h, p].join('') }

UrlHostname
	= ls:(l:UrlDomainLabel '.' { return l + '.' })* tl:UrlTopLabel
    { return ls.concat(tl).join('') }
    
UrlHostNumber
	= a:IPNum '.' b:IPNum '.' c:IPNum '.' d:IPNum
    { return [a, b, c, d].join('.') }
    
IPNum
	= ds:Digit+
    & {
      try {
         const d = parseInt( ds.join(''), 10 );
         
         return d > 0 && d < 256;
      } catch (e) {
         return false;
      }
    }
    { return ds.join('') }

UrlDomainLabel
	= a:AlphaDigit b:(AlphaDigit / '-')* c:AlphaDigit?
    { return [a].concat(b).concat(c).join('') }

UrlTopLabel
	= a:Alpha b:(AlphaDigit / '-')* c:AlphaDigit?
    { return [a].concat(b).concat(c).join('') }
    
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

UrlEscaped = '%' h:HexDigit l:HexDigit { return '%' + h + l }
UrlExtra = [!*'(),]
UrlNational = [{}|\^~\[\]`]
UrlPunctuation = [<>#%"]
UrlReserved = [;/?:@&=]
UrlSafe = [$\-_\.+]
UrlUChar = UrlUnreserved / UrlEscaped
UrlXChar = UrlUnreserved / UrlReserved / UrlEscaped
UrlUnreserved = Alpha / Digit / UrlSafe / UrlExtra

Alpha = [a-z]i
UpperAlpha = [A-Z]
LowerAlpha = [a-z]
Digit = [0-9]
HexDigit = [a-f0-9]i
AlphaDigit = [a-z0-9]i

EOL
	= [\n]

__
	= _+

_
	= [ \t]

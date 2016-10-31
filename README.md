# Simplenote Note Grammar and Parser

This library provides a grammar defining what kinds of content can be represented
inside a Simplenote note. Simplenote notes are plain-text documents but the text
can represent structured information such as URLs and Markdown.

This parser's goal is to identify such data and provide a structured output
suitable for syntax highlighting/formatting and introspection.

> Please note that this is still experimental and in its infancy.
> Please do not rely on this or expect it to be production-ready.

```js
import { parse as noteParser } from 'simplenote-grammar-pegjs'

function parseNote( note, parser ) {
    try {
        return parser( note )
    } catch (e) {
        return e
    }
}

const parsedNote = parseNote( 'Just some text', noteParser )
if ( parsedNote instanceof Error ) {
    abort()
}

parsedNote // === [ { type: 'text', text: 'Just some text', location: [ 0, 14 ] } ]
```

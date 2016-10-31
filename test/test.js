const { parse: noteParser } = require( '../dist/note-parser.js' )

function parseNote( note ) {
    try {
        return noteParser( note )
    } catch (e) {
        return e
    }
}


/**
 * Plain text
 * 
 * [ {
 *     "location": [ 0, 11 ],
 *     "type": "text",
 *     "text": "Just a test"
 * } ]
 */
function testParsesSimpleText() {
    const parsed = parseNote( 'Just a test' )

    return (
        ! ( parsed instanceof Error ) &&
        parsed.length === 1 &&
        parsed[0].location[ 0 ] === 0 &&
        parsed[0].location[ 1 ] === 11 &&
        parsed[0].type === 'text' &&
        parsed[0].text === 'Just a test' &&
        Object.keys( parsed[0] ).length === 3
    )
}

function runTests() {
    const hasPassed = (
        testParsesSimpleText()
    )

    console.log( hasPassed ? 'Passed' : 'Failed' )
    return hasPassed
}

runTests();
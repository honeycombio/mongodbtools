package logparser_test

import (
	"encoding/json"
	"fmt"

	"github.com/honeycombio/mongodbtools/logparser"
)

func ExampleParseLogLine() {
	line := "Mon Feb 23 03:20:19.670 [TTLMonitor] query local.system.indexes query: { expireAfterSeconds: { $exists: true } } ntoreturn:0 ntoskip:0 nscanned:0 keyUpdates:0 locks(micros) r:86 nreturned:0 reslen:20 0ms"
	doc, _ := logparser.ParseLogLine(line)
	buf, _ := json.Marshal(doc)
	fmt.Print(string(buf))
	// output:
	// {"context":"TTLMonitor","duration_ms":0,"keyUpdates":0,"locks(micros) r":86,"namespace":"local.system.indexes","nreturned":0,"nscanned":0,"ntoreturn":0,"ntoskip":0,"operation":"query","query":{"expireAfterSeconds":{"$exists":true}},"query_shape":"{ \"expireAfterSeconds\": { \"$exists\": 1 } }","reslen":20,"timestamp":"Mon Feb 23 03:20:19.670"}
}

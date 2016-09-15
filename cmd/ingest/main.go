package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/honeycombio/mongodbtools/logparser"
)

const (
	ctimeTimeFormat        = "Mon Jan _2 15:04:05.000"
	ctimeNoMSTimeFormat    = "Mon Jan _2 15:04:05"
	iso8601UTCTimeFormat   = "2006-01-02T15:04:05Z"
	iso8601LocalTimeFormat = "2006-01-02T15:04:05.999999999-0700"

	timestampFieldName  = "timestamp"
	namespaceFieldName  = "namespace"
	databaseFieldName   = "database"
	collectionFieldName = "collection"
	locksFieldName      = "locks"
)

var timestampFormats = []string{iso8601LocalTimeFormat, iso8601UTCTimeFormat, ctimeNoMSTimeFormat, ctimeTimeFormat}

func main() {
	file, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	var logparserTime time.Duration
	var logparserSuccess int64
	var logparserFailure int64

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		now := time.Now()
		_, err := logparser.ParseLogLine(line)

		logparserTime += time.Since(now)

		if err != nil {
			logparserFailure++
		} else {
			logparserSuccess++
		}

		if logparserSuccess > 0 && logparserSuccess % 50000 == 0 {
			fmt.Printf("%dms for %d successfully log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%dms for %d successfully log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
}

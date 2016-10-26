package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/honeycombio/mongodbtools/logparser"
)

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
		values, err := logparser.ParseLogLine(line)

		logparserTime += time.Since(now)

		if err != nil {
			logparserFailure++
			fmt.Println("FAIL:", line, err.Error())
		} else {
			logparserSuccess++
			fmt.Println("SUCCESS:", values)
		}

		if logparserSuccess > 0 && logparserSuccess%50000 == 0 {
			fmt.Printf("%dms for %d successfully parsed log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%dms for %d successfully parsed log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
}

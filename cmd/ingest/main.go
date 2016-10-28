package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"runtime/pprof"
	"time"

	"github.com/honeycombio/mongodbtools/logparser"
)

var cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
var failures = flag.Bool("fail", false, "write failed lines to stdout")
var successes = flag.Bool("success", false, "write successfully parsed maps to stdout")
var timings = flag.Bool("timings", false, "write intermediate timings/counts to stdout")

func main() {
	flag.Parse()
	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			log.Fatal(err)
		}
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}

	file, err := os.Open(flag.Args()[0])
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	var logparserTime time.Duration
	var logparserSuccess int64
	var logparserFailure int64

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024*1024), 0)
	for scanner.Scan() {
		line := scanner.Text()
		now := time.Now()
		values, err := logparser.ParseLogLine(line)

		logparserTime += time.Since(now)

		if err != nil {
			logparserFailure++
			if *failures {
				fmt.Println("FAIL:", line, err.Error())
			}
		} else {
			logparserSuccess++
			if *successes {
				fmt.Println("SUCCESS:", values)
			}
		}

		if *timings && logparserSuccess > 0 && logparserSuccess%50000 == 0 {
			fmt.Printf("%dms for %d successfully parsed log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%dms for %d successfully parsed log lines (%d lines/sec).  %d failures\n", logparserTime.Nanoseconds()/1e6, logparserSuccess, int64(float64(logparserSuccess)/logparserTime.Seconds()), logparserFailure)
}

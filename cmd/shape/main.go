package main

import (
	"fmt"
	"os"

	"github.com/honeycombio/mongodbtools/logparser"
	"github.com/honeycombio/mongodbtools/queryshape"
)

func main() {
	query, err := logparser.ParseQuery(os.Args[1])
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	fmt.Println("Query shape:", queryshape.GetQueryShape(query))
}

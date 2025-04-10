package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:10001", "listen address")
	flag.Parse()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s: %s %s", r.RemoteAddr, r.Method, r.URL)
		body, _ := io.ReadAll(r.Body)
		log.Printf("Content Length: %d\n%s\n", r.ContentLength, body)
		fmt.Fprintln(w, "OK")
	})

	log.Printf("listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}

package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"
)

var (
	gates map[string]bool
	mu    sync.Mutex
)

func main() {
	gates = make(map[string]bool)
	gates["step"] = false
	gates["rollout"] = false
	gates["promotion"] = false
	gates["rollback"] = false

	http.HandleFunc("/gate/", gateHandler)

	fmt.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func gateHandler(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) != 4 {
		http.Error(w, "Invalid URL", http.StatusBadRequest)
		return
	}

	gateType := parts[2]
	action := parts[3]

	mu.Lock()
	defer mu.Unlock()

	switch gateType {
	case "step", "rollout", "promotion", "rollback":
		handleGate(w, r, gateType, action)
	default:
		http.Error(w, "Invalid gate type", http.StatusBadRequest)
	}
}

func handleGate(w http.ResponseWriter, r *http.Request, gateType, action string) {
	switch action {
	case "check":
		if gates[gateType] {
			w.WriteHeader(http.StatusOK)
			fmt.Fprintf(w, "%s gate: Open (200 OK)\n", gateType)
		} else {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprintf(w, "%s gate: Closed (503 Service Unavailable)\n", gateType)
		}
	case "open":
		gates[gateType] = true
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "%s gate opened\n", gateType)
		if gateType == "step" {
			go func() {
				time.Sleep(10 * time.Second)
				mu.Lock()
				gates["step"] = false
				mu.Unlock()
				fmt.Println("Step gate automatically closed after 10 seconds")
			}()
		}
	case "close":
		gates[gateType] = false
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "%s gate closed\n", gateType)
	default:
		http.Error(w, "Invalid action", http.StatusBadRequest)
	}
}

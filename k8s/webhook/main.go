package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
)

// Alert represents a single alert in the AlertManager payload
type Alert struct {
	Annotations struct {
		Summary     string `json:"summary"`
		Description string `json:"description"`
	} `json:"annotations"`
	Status string `json:"status"`
	Labels struct {
		AlertName string `json:"alertname"`
		Namespace string `json:"namespace"`
	} `json:"labels"`
}

// AlertManagerPayload represents the webhook payload from AlertManager
type AlertManagerPayload struct {
	Alerts []Alert `json:"alerts"`
	Status string  `json:"status"`
}

func main() {
	addr := flag.String("addr", "0.0.0.0:10001", "listen address") // Changed to 0.0.0.0
	flag.Parse()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s: %s %s", r.RemoteAddr, r.Method, r.URL)

		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading body: %v", err)
			http.Error(w, "Error reading body", http.StatusBadRequest)
			return
		}

		var payload AlertManagerPayload
		if err := json.Unmarshal(body, &payload); err != nil {
			log.Printf("Error parsing JSON: %v", err)
			// Still print the raw body for debugging
			log.Printf("Raw body: %s", body)
			http.Error(w, "Error parsing JSON", http.StatusBadRequest)
			return
		}

		// Display only the summary and description for each alert
		for i, alert := range payload.Alerts {
			log.Printf("Alert #%d (%s):", i+1, alert.Status)
			log.Printf("  Name: %s", alert.Labels.AlertName)
			log.Printf("  Namespace: %s", alert.Labels.Namespace)
			log.Printf("  Summary: %s", alert.Annotations.Summary)
			log.Printf("  Description: %s", alert.Annotations.Description)
			log.Println()
		}

		fmt.Fprintln(w, "OK")
	})

	log.Printf("listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}

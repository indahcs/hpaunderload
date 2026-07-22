package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

const (
	defaultPort       = "8080"
	defaultIterations = 5_000_000
)

// getEnv retrieves the value of the environment variable named by the key.
// If the variable is present in the environment, its value is returned.
// Otherwise, the provided default value is returned.
func getEnv(name string, defaultValue string) string {
	if value, exists := os.LookupEnv(name); exists {
		return value
	}
	return defaultValue
}

// getIterations retrieves the number of iterations for the burn operation from the environment variable "BURN_ITERATIONS".
// If the environment variable is not set or cannot be converted to an integer, it returns the default value of 5,000,000
func getIterations() int {
	value := getEnv("BURN_ITERATIONS", "")
	// Convert the string value to an integer
	if iterations, err := strconv.Atoi(value); err == nil {
		return iterations
	}
	log.Printf("Invalid BURN_ITERATIONS value: %s. Using default: %d", value, defaultIterations)
	return defaultIterations
}

func burnCPU(iterations int) uint64 {
	var result uint64
	for i := 0; i < iterations; i++ {
		value := uint64(i)
		result = (result + value*value) % 1_000_000_007 // Use a large prime to avoid overflow
	}
	return result
}

func burnHandler(studentId string, iterations int) http.HandlerFunc {
	return func(
		writer http.ResponseWriter,
		request *http.Request,
	) {
		startTime := time.Now()
		result := burnCPU(iterations)
		duration := time.Since(startTime)

		writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
		writer.WriteHeader(http.StatusOK)

		_, err := fmt.Fprintf(writer, "OK burn %s result=%d duration=%s\n", studentId, result, duration)
		if err != nil {
			log.Printf("Error writing response for student ID: %s", studentId)
		}
		log.Printf("%s %s from=%s duration=%s", request.Method, request.URL.Path, request.RemoteAddr, duration)
	}
}

// healthHandler responds to health check requests with a simple "health check OK" message.
// healthHandler does not perform CPU-intensive work
// Kubernetes liveness and readiness probes use this endpoint to check the health of the application.
func healthHandler(writer http.ResponseWriter, request *http.Request) {
	writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
	writer.WriteHeader(http.StatusOK)
	_, err := fmt.Fprintln(writer, "health check OK")
	if err != nil {
		log.Printf("Could not write health check response: %v", err)
	}
}

func main() {
	studentId := getEnv("STUDENT_ID", "115029258")
	port := getEnv("PORT", defaultPort)
	iterations := getIterations()

	mux := http.NewServeMux()
	mux.HandleFunc("/", burnHandler(studentId, iterations))
	mux.HandleFunc("/health", healthHandler)

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("Starting CPU burn application studentID=%s port=%s iterations=%d", studentId, port, iterations)

	err := server.ListenAndServe()
	if err != nil && err != http.ErrServerClosed {
		log.Fatalf("Error starting server: %v", err)
	}
}

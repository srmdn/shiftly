package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type pinger struct{ err error }

func (p pinger) PingContext(context.Context) error { return p.err }

func TestHealth(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		body   string
	}{
		{name: "healthy", status: http.StatusOK, body: "{\"status\":\"ok\"}\n"},
		{name: "database unavailable", err: errors.New("down"), status: http.StatusServiceUnavailable, body: "{\"status\":\"unavailable\"}\n"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, "/api/health", nil)
			response := httptest.NewRecorder()
			New(pinger{err: test.err}).ServeHTTP(response, request)
			if response.Code != test.status || response.Body.String() != test.body {
				t.Fatalf("got status %d body %q", response.Code, response.Body.String())
			}
		})
	}
}

func TestHealthRejectsOtherMethods(t *testing.T) {
	request := httptest.NewRequest(http.MethodPost, "/api/health", nil)
	response := httptest.NewRecorder()
	New(pinger{}).ServeHTTP(response, request)
	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusMethodNotAllowed)
	}
}

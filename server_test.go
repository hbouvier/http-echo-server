package main

import "testing"

func TestServer(t *testing.T) {
	if true != true {
		t.Fatalf("Expected true to be true.")
	}
}

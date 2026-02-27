package main

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

// 1.3

// 1.805s
func BenchmarkOneDotOne(b *testing.B) {
	for b.Loop() {
		fmt.Println(strings.Join(os.Args[0:], " "))
	}
}

// 1.804s
func BenchmarkOneDotTwo(b *testing.B) {
	for b.Loop() {
		for i := 0; i < len(os.Args); i++ {
			fmt.Println(i, " ", os.Args[i])
		}
	}
}

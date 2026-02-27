package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	// 1.1
	fmt.Println("Exercise 1.1:")
	oneDotOne()

	// 1.2
	fmt.Println("Exercise 1.2:")
	oneDotTwo()
}

func oneDotOne() {
	fmt.Println(strings.Join(os.Args[0:], " "))
}

func oneDotTwo() {
	for i := 0; i < len(os.Args); i++ {
		fmt.Println(i, " ", os.Args[i])
	}
	fmt.Print("\n")
}

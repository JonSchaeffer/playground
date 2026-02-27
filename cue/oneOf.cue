#OneOf: {
	cluster: string
} | {
  direct_response: {
    status: int,
    body: string
  }
}

#E: {
	name: string
	#OneOf
}

ex1: #E & {
	name: "a choice"
	value: "hello"
}

ex2: #E & {
	name: "b choice"
  direct_response: {
    status: 2,
    body: "hello"
  }
}

route: #E & {
  direct_response: {status: 200, body: "OK"}
}


// ex3: #E & {
// 	name: "error none chosen"
// }

// ex4: #E & {
// 	name: "error both chosen"
// 	a:    "a"
// 	b:    "b"
// }

# A crappy makefile that updates all the intermediary files.

all: tests

tests: backpack.abi
	./backpack_tests.py

backpack.abi: backpack.sol
	solc backpack.sol --optimize 1 --json-abi file --binary file

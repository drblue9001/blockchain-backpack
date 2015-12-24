# A crappy makefile that updates all the intermediary files.

all: tests

tests: all_contracts
	./backpack_tests.py

load_one: all_contracts
	./load_one_item.py

# So solc's import directive doesn't actually scan the filesystem. This rule is
# minimally worthwhile until that's fixed, but does keep duplicate compilations
# from handling.
all_contracts: Backpack.abi
%.abi: %.sol
	solc --optimize --bin --abi $< -o build

clean:
	rm -Rf build/

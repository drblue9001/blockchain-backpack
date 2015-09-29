This is an experimental reimplementation of the Valve item system on top of the Ethereum blockchain.

The system is described in the following series of blog posts under website/.

* [The Blockchain Backpack](website/part1.md)
* [Blockchain Item Modification](website/part2.md)
* [Trading with the Blockchain Backpack](website/part3.md)
* [Interlude: Current Events and Why these Things have Value](website/part4.md)

The prototype itself lives under src/.

## Disclaimer

While all the code is Apache 2.0 licensed, this isn't a real project; it is proof of concept to show that such a system is possible, and a sequence of blog posts showing why it is desirable.

If you actually want to build a full version of the system I'm outlining, I suggest that you actually throw away everything I've written (except maybe the interface outlined here), and start over.

## Requirements

Assuming you're trying to build this locally (instead of just reading the code), you'll need a few things:

* [The solc compiler](https://github.com/ethereum/cpp-ethereum/wiki)
* [The pyethereum suite for the ethereum emulator](https://github.com/ethereum/pyethereum)
* [The ethertdd.py testing system](https://github.com/ethermarket/ethertdd.py)
* A Python interpreter
* Make

To run the test suite, run:

    cd src/
    make


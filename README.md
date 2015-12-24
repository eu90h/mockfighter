Introduction
=============
Mockfighter is a web API front-end to a limit order book exchange, based on [Stockfighter](http://www.stockfighter.io).
It requires [Racket](http://www.racket-lang.org) to run.

The goal is to be 1-1 compatible with the Stockfighter API.

Currently, two bots are provided: a noisy trader and a market maker (that doesn't understand its job).
Both are extremely stupid, as anything better would probably give away solutions to Stockfighter levels.

Background
==========
[Stockfighter](http://stockfighter.io) is a series of challenges revolving around stock markets and automated trading. Mockfighter is essentially an emulator for the game.

A limit order book exchange is a type of market where the participants deal with each other via a limit order book.
A limit order book is a sort-of dual ledger keeping track of sell and buy orders (called asks and bids respectively).

It may help to think of an order book as a priority queue, prioritized by price first, order placement time second (with earlier orders going first).

A limit order is basically an order that specifies a extremal price. For example, a buy limit order for 10 shares at $2.15
will be filled for any price up to $2.15. A sell limit order for 10 shares at $2.15 will, on the other hand,
be filled for any price greater than or equal to $2.15.

The limit order stands in contrast to the market order. The market order specifies only a quantity of shares to be traded.
A market order will purchase that quantity of shares at whatever price is being offered on the market.

Limit orders give guarantees on the execution price, but at the cost of execution certainty. Market orders are the exact opposite: guaranteeing execution certainty at the cost of price certainty.

Installation
============
`raco pkg install https://github.com/eu90h/mockfighter/`
or install from DrRacket.

Quickstart
==========
The following snippet shows how to run the Mockfighter server on http://localhost:8000/

`` (require mockfighter) ``

`` (define server-thread (run-mockfighter)) ``

This will begin running the server in a separate thread. 

Next, create an instance of a level by POSTing to http://localhost:8000/gm/levels/any-string-here

This will create an instance of the level "any-string-here".

The bots will begin trading two seconds after an instance is created.

Mockfighter requires api keys, which are set in request headers. Any string will do here.

How It Works
============
A player registers with the game master by making an empty POST to http://localhost:8000/gm/levels/any-string-here. This creates a new instance of a level named any-string-here.

A json object is returned containing an account ID, a venue name, and a stock symbol.

Additionally, the bots are created at this point. The stock is assigned a fair market value
and the traders are informed of this value before making trades.

Every trading day lasts 5 seconds. At the end of each day, the fair market value changes.

The player interacts with the market by making HTTP GET and POST requests to various urls, blah blah blah :P

Differences
===========
Getting a stock's orderbook returns more detailed order data than Stockfighter.

Only market and limit orders are supported.

Quotes don't contain bid/ask depth, just best offer sizes.

GM API not completely implemented (only starting levels is supported).

New level cmd returns different response

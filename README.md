Introduction
=============
Mockfighter is a web API front-end to a limit order book exchange, based on [Stockfighter](http://www.stockfighter.io).
It requires [Racket](http://www.racket-lang.org) to run.

The goal is to be 1-1 compatible with the Stockfighter API.

Currently, two bots are provided: a noisy trader and a market maker (that doesn't understand its job).
Both are extremely stupid, as anything better would probably give away solutions to Stockfighter levels.

Installation
============
`raco pkg install https://github.com/eu90h/mockfighter/`
or install from DrRacket.

Quickstart
==========
The following snippet shows how to run the Mockfighter server on http://localhost:8000/

`` (require mockfighter) ``

`` (define-values (server-thread begin-trading) (run-mockfighter)) ``

This will begin running the server in a separate thread, which is returned
along with a thunk begin-trading which, when called, starts the bots trading loop.

Next, create an instance of a level by POSTing to http://localhost:8000/gm/levels/any-string-here

This will create an instance of the level "any-string-here".

Then you may call the begin-trading procedure to spur the traders into action.

Mockfighter requires (like Stockfighter) api keys, which are set in request headers. Any string will do here.

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

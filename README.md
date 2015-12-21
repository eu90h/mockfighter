Introduction
=============
Mockfighter is a web API front-end to a limit order book, based on [Stockfighter](stockfighter.io).
It requires [Racket](racket-lang.org) to run.

The goal is to be 1-1 compatible with the stockfighter API.

Currently, two bots are provided: a noisy trader and a market maker (that doesn't understand its job).
Both are extremely stupid, as anything better would probably give away solutions to Stockfighter levels.

Installation
============
`raco pkg install https://github.com/eu90h/mockfighter/`
or install from DrRacket.

Quickstart
==========
The following snippet shows how to run the mockfighter server on http://localhost:8000/

`` (require mockfighter) ``

`` (define-values (server-thread begin-trading) (run-mockfighter)) ``

This will begin running the server in a separate thread, which is returned
along with a thunk begin-trading which, when called, starts the bots trading loop.

Next, create an instance by making a GET request to http://localhost:8000/gm/api/instances/new

Then you may call the begin-trading procedure to spur the traders into action.

Mockfighter requires (like Stockfighter) api keys, which are set in request headers. Any string will do here.

How It Works
============
A player registers with the game master by making a GET request to http://localhost:8000/gm/api/instances/new. This creates a new instance of an exchange, providing one stock.

A json object is returned containing an account ID, a venue name, and a stock symbol.

Additionally, the bots are created at this point. The stock is assigned a fair market value
and the traders are informed of this value before making trades.

Every trading day lasts 5 seconds. At the end of each day, the fair market value changes.

The player interacts with the market by making HTTP GET and POST requests to various urls, blah blah blah :P

Differences
===========
Getting a stock's orderbook returns more detailed order data than stockfighter.

Only market and limit orders are supported.

Quotes don't contain bid/ask depth, just best offer sizes.

Websockets aren't supported yet.

I hope to fix most of this soon.


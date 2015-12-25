Introduction
=============
Mockfighter is a web API front-end to a limit order book exchange, based on [Stockfighter](http://www.stockfighter.io).
It requires [Racket](http://www.racket-lang.org) to run.

The goal is to be 1-1 compatible with the Stockfighter API.

Currently, three bots are provided: noisy traders, retail traders, and market makers.
All are extremely stupid, as anything better would probably give away solutions to Stockfighter levels.

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
Mockfighter requires the Racket Stockfighter client, located [here](https://github.com/eu90h/stockfighter-racket/).

After that's installed, you can install Mockfighter by running the command 
`raco pkg install https://github.com/eu90h/mockfighter/`
or install from DrRacket.

Quickstart
==========
The following snippet shows how to run the Mockfighter server on `http://localhost:8000/`

`` (require mockfighter) ``

`` (define server-thread (run-mockfighter)) ``

This will begin running the server in a separate thread. 

Next, create an instance of a level by POSTing to `http://localhost:8000/gm/levels/<any-string-here>`

This will create an instance of the level "any-string-here".

The bots will begin trading two seconds after an instance is created.

Mockfighter requires an api key, which should be set in a `X-Starfighter-Authorization:<api-key-here>` HTTP header. Any string will do here.

Additionally, the GM API requires a header `Cookie:api_key=<api-key-here>` to be set. The same key should be used for both headers.

How It Works
============
A player registers with the game master by making an empty POST to `http://localhost:8000/gm/levels/<any-string-here>`. This creates a new instance of a level named any-string-here.

A json object is returned containing an account ID, a venue name, and a stock symbol.

Additionally, the bots are created at this point. The stock is assigned a fair market value
and the traders are informed of this value before making trades.

Every trading day lasts 5 seconds. At the end of each day, the fair market value changes.

The player interacts with the market by making HTTP GET and POST requests to various urls (see the reference below, or the Stockfighter docs).

GM API Reference
================
* to start a new level: POST to `http://localhost:8000/gm/levels/<any-string-here>`

OrderBook API Reference
=======================
All these commands have the url `http://localhost:8000/ob/api/` as a root. For more detailed information, see the Stockfighter API docs.

* to post an order: POST a json object containing your account number, venue name, stock name, price, qty, direction, and order type to `venues/<venue-name>/stocks/<stock-name>/orders`

* to cancel an order: POST to `venues/<venue-name>/stocks/<stock-name>/orders/<order-id>/cancel`

* to get a market quote: GET `venues/<venue-name>/stocks/<stock-name>/quote`

* to get a snapshot of the orderbook: GET `venues/<venue-name>/stocks/<stock-name>`

* to get an order's status: GET `venues/<venue-name>/stocks/<stock-name>/orders/<order-id>`

Ticker & Order Execution Feeds
===============================
As in Stockfighter, it's possible to open ticker and execution feeds using websockets.

Once a level is instantiated (see GM API reference section), you may open the feeds.

* to open the ticker feed: open a websocket connection to the address `ws://127.0.0.1:8001/ob/api/ws/<account-id>/venues/<venue-name>/tickertape/stocks/<stock-name>`. Alternatively, you can use the less-specific address `ws://127.0.0.1:8001/ob/api/ws/<account-id>/venues/<venue-name>/tickertape`.

* to open the executions feed: open a websocket connection to the address `ws://127.0.0.1:8001/ob/api/ws/<account-id>/venues/<venue-name>/executions/stocks/<stock-name>`. Alternatively, you can use the less-specific address `ws://127.0.0.1:8001/ob/api/ws/<account-id>/venues/<venue-name>/executions`.

The web sockets time out after about 5 minutes.

Differences
===========
Getting a stock's orderbook returns more detailed order data than Stockfighter.

Only market and limit orders are supported.

GM API not completely implemented (only starting levels is supported).

New level cmd returns different response

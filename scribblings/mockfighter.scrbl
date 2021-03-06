#lang scribble/manual
@require[@for-label[mockfighter
                    racket/base]]

@title{mockfighter}
@author{eu90h}

@defmodule[mockfighter]

@section[#:tag "intro"]{Introduction}
Mockfighter is a web API frontend for a limit order book exchange. The API was designed with the
intent of being as close to 1-1 with Stockfighter's API as possible.

Currently, two bots are provided: a noisy trader and a market maker (that doesn't understand its job).
Both are extremely stupid, as anything better would probably give away solutions to Stockfighter levels.

@section[#:tag "quick"]{Quickstart}
The following snippet shows how to run the mockfighter server on http://localhost:8000/
@racketblock[(require mockfighter)
             (define server-thread (run-mockfighter))]
This will begin running the server in a separate thread.

Next, create an instance by making a POST request to http://localhost:8000/gm/levels/any-string-here

This creates an instance of the level called any-string-here.

The bots will begin trading two seconds after creating an instance. The bots may be disabled like so:
@racketblock[(run-mockfighter #:bots #f)]

Furthermore, you may run the server on a port other than 8000 by setting the port option:
@racketblock[(run-mockfighter #:port port-number)]

Mockfighter requires (like Stockfighter) api keys, which are set in request headers. Any string will do here.

@section[#:tag "more"]{How It Works}
A player registers with the game master by making a GET request to http://localhost:8000/gm/levels/any-string-here. This creates a new instance of a level named any-string-here.

A json object is returned containing an account ID, a venue name, and a stock symbol.

Additionally, the bots are created at this point. The stock is assigned a fair market value
and the traders are informed of this value before making trades.

Every trading day lasts 5 seconds. At the end of each day, the fair market value changes.

The player interacts with the market by making HTTP GET and POST requests to various urls, blah blah blah :P

@section[#:tag "differences"]{Differences from Stockfighter}
GM API not completely implemented.

@section[#:tag "api"]{API Reference}
I was able to use my stockfighter client without modification and it seems to work, so hopefully you can too.
For more information about the API see the Stockfighter reference or your client's documentation.
Since the goal is compatibility, any deviations from the Stockfighter API could be considered a bug, so report any oddities.

@section[#:tag "end"]{Bugs}
I'm sure many exist. This was written fairly quickly and has had only minor testing (although all parts have been tested.)
If you find something let me know on GitHub!

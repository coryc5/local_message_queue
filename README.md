# LocalMessageQueue
[![CircleCI](https://circleci.com/gh/coryc5/local_message_queue/tree/master.svg?style=svg)](https://circleci.com/gh/coryc5/local_message_queue/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/coryc5/local_message_queue/badge.svg?branch=master)](https://coveralls.io/github/coryc5/local_message_queue?branch=master)

 LocalMessageQueue is a framework for building asynchronous and observable pipelines locally within an Elixir application. See [this blog post](https://dev.to/coryc5/localmessagequeue-35i7) and the module docs for more details.

## Installation

The package can be installed by adding `local_message_queue` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:local_message_queue, "~> 0.1.0", github: "coryc5/local_message_queue"}
  ]
end
```

## Development Mix Tasks

* mix coveralls - generate coverage
* mix dialyzer - run static analysis

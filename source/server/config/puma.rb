#!/usr/bin/env puma

environment 'production'
rackup "#{__dir__}/config.ru"

# A test-run waits on the docker daemon, runner computes ~nothing itself:
# the tar and gzip of a typical test-run payload cost under a millisecond.
# The Ruby MRI releases the GVL for docker daemon wait, so threads and
# process serve test-run requests equally well. Throughput was measured both
# ways, at 8 and at 16 requests at once, and does not change.
#
# So the worker count is not what decides how many test-runs the node can
# serve. Two is for the workers themselves: one keeps serving while the other
# restarts, and a phased restart needs more than one. Ten, which is what
# Etc.nprocessors answers on a 4-core host, was ten ruby heaps for no gain.
#
# We are conservative with threads. Consider what happens when 64 learners
# press [test] at the same time, on 4 cores, under 8 vs 64 threads.
# ┌─────────────────────────┬───────────────────────┬──────────────────────────┐
# │          step           │        8 threads      │         64 threads       │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ accepted at once        │ 8                     │ 64                       │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ kata containers running │ 8                     │ 64                       │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ CPU each gets           │ 1/2 core              │ 1/16 core                │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ 2s test run takes       │ 4s                    │ 32s                      │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ against max_seconds=10  │ Red|Amber|Green       │ times out                │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ the other 56            │ queued but get a RAG  │ all running, all failing │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ container held for      │ 4s                    │ the full 10s             │
# ├─────────────────────────┼───────────────────────┼──────────────────────────┤
# │ learner's next move     │ reads the result      │ presses again            │
# └─────────────────────────┴───────────────────────┴──────────────────────────┘

workers(2)
threads(8, 8)
